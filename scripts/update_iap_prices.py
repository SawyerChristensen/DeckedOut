#!/usr/bin/env python3
"""Push in-app-purchase price changes to App Store Connect from the .storekit file.

`upload_iaps.py` is "ensure"-based: it only sets a price on an IAP that has none
yet, and never touches one that's already priced. This script is the companion
for the other half — changing the price of IAPs that are already live.

Source of truth is the project's "StoreKit Config.storekit" file. For every
NonConsumable product in it:

    1. find the matching IAP in App Store Connect (it must already exist)
    2. read its current USA base price
    3. if it differs from displayPrice, replace the price schedule with a single
       manual price at the new point, effective immediately (startDate = null)

Changing a price replaces the whole manual price schedule, so any future-dated
price changes you'd scheduled by hand are dropped. Territory prices continue to
be equalized by App Store Connect off the USA base, same as upload_iaps.py.

Usage:
    ./run_update_prices.sh --dry-run                 # show every planned change
    ./run_update_prices.sh                           # apply (prompts to confirm)
    ./run_update_prices.sh --yes                     # apply without the prompt
    ./run_update_prices.sh --only RedFoxEnchanted    # limit to matching product IDs

Reads the same credentials as upload_iaps.py / upload_metadata.py (from
~/.appstoreconnect/config.env, scripts/.env, or the environment):
    ASC_KEY_ID         App Store Connect API key ID (10-char string)
    ASC_ISSUER_ID      App Store Connect issuer ID (UUID)
    ASC_KEY_PATH       Path to the .p8 private key file
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path

import jwt
import requests

SCRIPT_DIR = Path(__file__).resolve().parent
STOREKIT_PATH = SCRIPT_DIR.parent / "StoreKit Config.storekit"
ASC_BASE = "https://api.appstoreconnect.apple.com"
BUNDLE_ID = "Sawyer.DeckedOut"

# All theme purchases carry a single USA base price; App Store Connect equalizes
# every other territory off it. Prices are read and written against this base.
BASE_TERRITORY = "USA"

# Where credentials live. Auto-loaded so you never have to `source` them per run.
CONFIG_PATHS = [
    Path("~/.appstoreconnect/config.env").expanduser(),
    SCRIPT_DIR / ".env",
]


def load_config() -> None:
    """Load KEY=VALUE pairs from config.env files into os.environ (no overwrite)."""
    for config_path in CONFIG_PATHS:
        if not config_path.exists():
            continue
        for raw in config_path.read_text().splitlines():
            line = raw.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            key = key.strip()
            value = value.strip().strip('"').strip("'")
            if key and key not in os.environ:
                os.environ[key] = value


def require_env(name: str) -> str:
    val = os.environ.get(name)
    if not val:
        sys.exit(f"Missing required env var: {name}")
    return val


def make_jwt() -> str:
    key_id = require_env("ASC_KEY_ID")
    issuer_id = require_env("ASC_ISSUER_ID")
    key_path = Path(require_env("ASC_KEY_PATH")).expanduser()
    if not key_path.exists():
        sys.exit(f"ASC_KEY_PATH does not exist: {key_path}")
    private_key = key_path.read_text()
    now = int(time.time())
    payload = {
        "iss": issuer_id,
        "iat": now,
        "exp": now + 20 * 60,  # max 20 minutes
        "aud": "appstoreconnect-v1",
    }
    return jwt.encode(payload, private_key, algorithm="ES256",
                      headers={"kid": key_id, "typ": "JWT"})


class ASCClient:
    TOKEN_TTL = 15 * 60  # re-mint the JWT before Apple's 20-minute cap

    def __init__(self, dry_run: bool = False) -> None:
        self.dry_run = dry_run
        self.session = requests.Session()
        self._refresh_token()

    def _refresh_token(self) -> None:
        self.token = make_jwt()
        self.token_minted_at = time.time()
        self.headers = {
            "Authorization": f"Bearer {self.token}",
            "Content-Type": "application/json",
        }

    def _ensure_fresh_token(self) -> None:
        if time.time() - self.token_minted_at >= self.TOKEN_TTL:
            self._refresh_token()

    def _url(self, path: str) -> str:
        return path if path.startswith("http") else f"{ASC_BASE}/{path.lstrip('/')}"

    def _send(self, method: str, url: str, label: str, *, params=None, body=None,
              allow_404: bool = False) -> requests.Response | None:
        """Issue a request, retrying transient 5xx/429 with backoff.

        Returns None when allow_404 is set and the resource doesn't exist.
        """
        max_attempts = 5
        for attempt in range(1, max_attempts + 1):
            self._ensure_fresh_token()
            try:
                r = self.session.request(method, url, headers=self.headers,
                                         params=params, json=body, timeout=60)
            except requests.exceptions.RequestException as exc:
                if attempt < max_attempts:
                    wait = 2 ** attempt
                    print(f"    ⚠ {method} {label} -> {type(exc).__name__}, retrying "
                          f"in {wait}s (attempt {attempt}/{max_attempts - 1})")
                    time.sleep(wait)
                    continue
                sys.exit(f"{method} {label} failed after {max_attempts} attempts: {exc}")
            if r.ok:
                return r
            if allow_404 and r.status_code == 404:
                return None
            if r.status_code in (429, 500, 502, 503, 504) and attempt < max_attempts:
                wait = 2 ** attempt
                print(f"    ⚠ {method} {label} -> {r.status_code}, retrying in {wait}s "
                      f"(attempt {attempt}/{max_attempts - 1})")
                time.sleep(wait)
                continue
            sys.exit(f"{method} {label} failed ({r.status_code}): {r.text}")
        sys.exit(f"{method} {label} failed after {max_attempts} attempts")

    def get(self, path: str, params=None, allow_404: bool = False):
        r = self._send("GET", self._url(path), path, params=params, allow_404=allow_404)
        return r.json() if r is not None else None

    def get_all(self, path: str, params=None) -> list:
        """GET every page of a list endpoint, following links.next."""
        params = dict(params or {})
        params.setdefault("limit", 200)
        out: list = []
        url = self._url(path)
        while url:
            r = self._send("GET", url, path, params=params)
            payload = r.json()
            out.extend(payload.get("data", []))
            url = payload.get("links", {}).get("next")
            params = None  # links.next already carries the query string
        return out

    def get_page(self, path: str, params=None) -> dict:
        """GET a single page, returning the full payload (data + included)."""
        r = self._send("GET", self._url(path), path, params=params)
        return r.json()

    def post(self, path: str, body: dict) -> dict:
        if self.dry_run:
            print(f"    [dry-run] POST {path}")
            return {"data": {"id": "dry-run-id"}}
        return self._send("POST", self._url(path), path, body=body).json()


# ---------- StoreKit parsing ----------

def load_products(only: list[str] | None) -> list[dict]:
    """Read NonConsumable products from the .storekit file as {product_id, price}."""
    if not STOREKIT_PATH.exists():
        sys.exit(f"StoreKit config not found: {STOREKIT_PATH}")
    config = json.loads(STOREKIT_PATH.read_text())
    products = []
    for p in config.get("products", []):
        if p.get("type") != "NonConsumable":
            continue
        product_id = p["productID"]
        if only and not any(token.lower() in product_id.lower() for token in only):
            continue
        products.append({
            "product_id": product_id,
            "reference_name": p.get("referenceName", product_id),
            "price": p["displayPrice"],
        })
    return products


# ---------- App Store Connect ----------

def find_app_id(client: ASCClient) -> str:
    data = client.get("v1/apps", params={"filter[bundleId]": BUNDLE_ID})["data"]
    if not data:
        sys.exit(f"No app found with bundle ID {BUNDLE_ID}")
    return data[0]["id"]


def existing_iaps(client: ASCClient, app_id: str) -> dict[str, dict]:
    """Map productId -> IAP resource for every existing in-app purchase."""
    data = client.get_all(f"v1/apps/{app_id}/inAppPurchasesV2")
    return {iap["attributes"]["productId"]: iap for iap in data}


def current_prices(client: ASCClient, iap_id: str) -> list[tuple[str | None, str]]:
    """Return [(startDate, customerPrice)] for the IAP's manual USA prices.

    The price schedule shares the IAP's id and always exists; an IAP that's never
    been priced just has an empty manualPrices list.
    """
    payload = client.get_page(
        f"v1/inAppPurchasePriceSchedules/{iap_id}/manualPrices",
        params={"include": "inAppPurchasePricePoint", "limit": 200},
    )
    point_price = {
        inc["id"]: inc["attributes"]["customerPrice"]
        for inc in payload.get("included", [])
        if inc["type"] == "inAppPurchasePricePoints"
    }
    out: list[tuple[str | None, str]] = []
    for price in payload.get("data", []):
        point = price.get("relationships", {}).get(
            "inAppPurchasePricePoint", {}).get("data") or {}
        customer_price = point_price.get(point.get("id"))
        if customer_price is not None:
            out.append((price["attributes"].get("startDate"), customer_price))
    return out


def effective_price(prices: list[tuple[str | None, str]]) -> str | None:
    """The price in force today: latest startDate that is null or already past."""
    today = time.strftime("%Y-%m-%d")
    active = [(sd or "", cp) for sd, cp in prices if (sd or "") <= today]
    if not active:
        return None
    return max(active)[1]


def find_price_point(client: ASCClient, iap_id: str, price: str) -> str:
    """Return the USA price-point id whose customerPrice equals `price`."""
    points = client.get_all(
        f"v2/inAppPurchases/{iap_id}/pricePoints",
        params={"filter[territory]": BASE_TERRITORY, "include": "territory"},
    )
    for pt in points:
        if pt["attributes"]["customerPrice"] == price:
            return pt["id"]
    available = sorted({pt["attributes"]["customerPrice"] for pt in points})
    sys.exit(f"No {BASE_TERRITORY} price point for {price}. Available: {available[:20]}...")


def set_price(client: ASCClient, iap_id: str, price: str) -> None:
    """Replace the IAP's price schedule with one manual price, effective now."""
    point_id = find_price_point(client, iap_id, price)
    client.post("v1/inAppPurchasePriceSchedules", {
        "data": {
            "type": "inAppPurchasePriceSchedules",
            "relationships": {
                "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap_id}},
                "baseTerritory": {"data": {"type": "territories", "id": BASE_TERRITORY}},
                "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": "${newprice}"}]},
            },
        },
        "included": [{
            "type": "inAppPurchasePrices",
            "id": "${newprice}",
            "attributes": {"startDate": None},
            "relationships": {
                "inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iap_id}},
                "inAppPurchasePricePoint": {
                    "data": {"type": "inAppPurchasePricePoints", "id": point_id}
                },
            },
        }],
    })


# ---------- Main ----------

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--dry-run", action="store_true",
                        help="Print the planned changes without making them.")
    parser.add_argument("--yes", action="store_true",
                        help="Apply without the confirmation prompt.")
    parser.add_argument("--only", help="Comma-separated substrings; only matching "
                                        "product IDs are processed.")
    args = parser.parse_args()

    only = [s.strip() for s in args.only.split(",")] if args.only else None
    products = load_products(only)
    if not products:
        sys.exit("No matching NonConsumable products found in the .storekit file.")

    load_config()
    client = ASCClient(dry_run=args.dry_run)

    print(f"Looking up app {BUNDLE_ID}...")
    app_id = find_app_id(client)
    existing = existing_iaps(client, app_id)
    print(f"Found {len(existing)} existing IAP(s) in App Store Connect.\n")

    planned: list[tuple[str, str, str]] = []  # (product_id, from_price, to_price)
    missing: list[str] = []
    unchanged = 0

    for product in products:
        pid = product["product_id"]
        target = product["price"]
        iap = existing.get(pid)
        if iap is None:
            missing.append(pid)
            continue
        now_price = effective_price(current_prices(client, iap["id"]))
        if now_price == target:
            unchanged += 1
            continue
        planned.append((pid, now_price or "unset", target))
        print(f"  {pid}\n      ${now_price or 'unset'}  ->  ${target}")

    if missing:
        print(f"\n⚠ {len(missing)} product(s) in the .storekit file have no IAP in "
              f"App Store Connect — run upload_iaps.py first:")
        for pid in missing:
            print(f"    {pid}")

    print(f"\n{len(planned)} to change, {unchanged} already at target price"
          + (f", {len(missing)} missing" if missing else "") + ".")

    if not planned:
        return
    if args.dry_run:
        print("\n[dry-run] no changes made.")
        return
    if not args.yes:
        reply = input("\nApply these price changes? Type 'yes' to proceed: ").strip()
        if reply != "yes":
            print("Aborted.")
            return

    print()
    for pid, from_price, to_price in planned:
        print(f"  ~ {pid}: ${from_price} -> ${to_price}")
        set_price(client, existing[pid]["id"], to_price)

    print(f"\nDone. {len(planned)} price(s) updated.")
    print("No app submission needed: price changes to already-approved IAPs "
          "propagate automatically (usually within 24h), territory by territory.")


if __name__ == "__main__":
    main()
