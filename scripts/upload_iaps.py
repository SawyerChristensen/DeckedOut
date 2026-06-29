#!/usr/bin/env python3
"""Create / complete DeckedOut in-app purchases in App Store Connect.

Source of truth is the project's "StoreKit Config.storekit" file. Every
NonConsumable product in it is reconciled against App Store Connect:

    1. the IAP itself (reference name, product ID, type, family sharing)
    2. its English localization (display name + description)
    3. its territory availability (all territories, per the in-app region gating)
    4. its price (USA base price taken from displayPrice)

The script is idempotent and "ensure"-based: anything that already exists is
left alone, anything missing is created. So an IAP you started by hand (e.g. the
American/Austrian flags) gets finished rather than duplicated, and re-running is
always safe.

Usage:
    ./run_iaps.sh --dry-run                 # preview every call, change nothing
    ./run_iaps.sh                           # reconcile every theme IAP
    ./run_iaps.sh --only AmericanFlag,Koi   # limit to product IDs containing these
    ./run_iaps.sh --price-tier-list IAP_ID  # debug: dump USA price points for an IAP

Reads the same credentials as upload_metadata.py (from
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

# All theme purchases are sold at a single USA base price; territory pricing is
# equalized by App Store Connect off this base. Region gating happens in-app, so
# every IAP is available in every territory.
BASE_TERRITORY = "USA"

# StoreKit product "type" -> App Store Connect inAppPurchaseType.
TYPE_MAP = {
    "NonConsumable": "NON_CONSUMABLE",
    "Consumable": "CONSUMABLE",
    "NonRenewingSubscription": "NON_RENEWING_SUBSCRIPTION",
}

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

        Returns None when allow_404 is set and the resource doesn't exist — used
        to probe optional sub-resources (a missing price schedule, etc.).
        """
        max_attempts = 5
        for attempt in range(1, max_attempts + 1):
            self._ensure_fresh_token()
            r = self.session.request(method, url, headers=self.headers,
                                     params=params, json=body, timeout=60)
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

    def post(self, path: str, body: dict) -> dict:
        if self.dry_run:
            print(f"    [dry-run] POST {path}")
            return {"data": {"id": "dry-run-id"}}
        return self._send("POST", self._url(path), path, body=body).json()

    def patch(self, path: str, body: dict) -> dict:
        if self.dry_run:
            print(f"    [dry-run] PATCH {path}")
            return {"data": {"id": "dry-run-id"}}
        return self._send("PATCH", self._url(path), path, body=body).json()


# ---------- StoreKit parsing ----------

def asc_locale(storekit_locale: str) -> str:
    """Map a StoreKit locale code to its App Store Connect equivalent.

    StoreKit uses underscores (en_US, de_DE, pt_BR, zh_Hans); ASC uses hyphens
    (en-US, de-DE, pt-BR, zh-Hans). The only difference is the separator, so a
    straight replace covers every code we use.
    """
    return storekit_locale.replace("_", "-")


def load_products(only: list[str] | None) -> list[dict]:
    """Read NonConsumable products from the .storekit file as normalized dicts.

    Every localization in the .storekit file is carried through (not just the
    English one), with locale codes mapped to their ASC form.
    """
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
        en = next((loc for loc in p.get("localizations", [])
                   if loc.get("locale") == "en_US"), None)
        if not en:
            print(f"  ⚠ {product_id} has no en_US localization in the .storekit file; skipping")
            continue
        localizations = [
            {
                "locale": asc_locale(loc["locale"]),
                "name": loc["displayName"],
                "description": loc.get("description", ""),
            }
            for loc in p.get("localizations", [])
        ]
        products.append({
            "product_id": product_id,
            "reference_name": p.get("referenceName", en["displayName"]),
            "type": TYPE_MAP[p["type"]],
            "family_sharable": bool(p.get("familyShareable", False)),
            "localizations": localizations,
            "price": p["displayPrice"],
        })
    return products


# ---------- Reconcilers ----------

def find_app_id(client: ASCClient) -> str:
    data = client.get("v1/apps", params={"filter[bundleId]": BUNDLE_ID})["data"]
    if not data:
        sys.exit(f"No app found with bundle ID {BUNDLE_ID}")
    return data[0]["id"]


def existing_iaps(client: ASCClient, app_id: str) -> dict[str, dict]:
    """Map productId -> IAP resource for every existing in-app purchase."""
    data = client.get_all(f"v1/apps/{app_id}/inAppPurchasesV2")
    return {iap["attributes"]["productId"]: iap for iap in data}


def ensure_iap(client: ASCClient, app_id: str, product: dict,
               existing: dict[str, dict]) -> str | None:
    """Create the IAP if missing. Returns its ASC id (None in dry-run for new ones)."""
    pid = product["product_id"]
    if pid in existing:
        print(f"  • IAP exists ({existing[pid]['id']})")
        return existing[pid]["id"]
    print(f"  + creating IAP")
    resp = client.post("v2/inAppPurchases", {
        "data": {
            "type": "inAppPurchases",
            "attributes": {
                "name": product["reference_name"],
                "productId": pid,
                "inAppPurchaseType": product["type"],
                "familySharable": product["family_sharable"],
            },
            "relationships": {
                "app": {"data": {"type": "apps", "id": app_id}},
            },
        }
    })
    iap_id = resp["data"]["id"]
    return None if iap_id == "dry-run-id" else iap_id


def ensure_localizations(client: ASCClient, iap_id: str, product: dict) -> None:
    """Reconcile every locale from the .storekit file onto the IAP.

    Missing locales are created; existing ones whose name or description drifted
    from the .storekit file are updated. Unchanged locales are left alone.
    """
    existing = client.get_all(f"v2/inAppPurchases/{iap_id}/inAppPurchaseLocalizations")
    # An IAP that's live and being edited can have two localizations for the same
    # locale: an APPROVED (published) one and a PREPARE_FOR_SUBMISSION (editable
    # draft) one. Always prefer the editable draft — APPROVED metadata can't be
    # patched and reflects what's already live.
    by_locale: dict[str, dict] = {}
    for entry in existing:
        locale = entry["attributes"]["locale"]
        kept = by_locale.get(locale)
        if (kept is None
                or (kept["attributes"].get("state") == "APPROVED"
                    and entry["attributes"].get("state") != "APPROVED")):
            by_locale[locale] = entry
    for loc in product["localizations"]:
        locale = loc["locale"]
        current = by_locale.get(locale)
        if current is None:
            print(f"  + creating {locale} localization")
            client.post("v1/inAppPurchaseLocalizations", {
                "data": {
                    "type": "inAppPurchaseLocalizations",
                    "attributes": {
                        "locale": locale,
                        "name": loc["name"],
                        "description": loc["description"],
                    },
                    "relationships": {
                        "inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iap_id}},
                    },
                }
            })
            continue
        attrs = current["attributes"]
        if attrs.get("name") == loc["name"] and (attrs.get("description") or "") == loc["description"]:
            print(f"  • {locale} localization up to date")
            continue
        if attrs.get("state") == "APPROVED":
            print(f"  ⚠ {locale} localization differs but is APPROVED (live); leaving it alone")
            continue
        print(f"  ~ updating {locale} localization")
        client.patch(f"v1/inAppPurchaseLocalizations/{current['id']}", {
            "data": {
                "type": "inAppPurchaseLocalizations",
                "id": current["id"],
                "attributes": {
                    "name": loc["name"],
                    "description": loc["description"],
                },
            }
        })


def ensure_availability(client: ASCClient, iap_id: str,
                        all_territories: list[str]) -> None:
    """Make the IAP available in every territory (region gating is done in-app)."""
    current = client.get(f"v2/inAppPurchases/{iap_id}/inAppPurchaseAvailability",
                         allow_404=True)
    if current and current.get("data"):
        print(f"  • availability already configured")
        return
    print(f"  + creating availability ({len(all_territories)} territories)")
    client.post("v1/inAppPurchaseAvailabilities", {
        "data": {
            "type": "inAppPurchaseAvailabilities",
            "attributes": {"availableInNewTerritories": True},
            "relationships": {
                "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap_id}},
                "availableTerritories": {
                    "data": [{"type": "territories", "id": t} for t in all_territories]
                },
            },
        }
    })


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


def ensure_price(client: ASCClient, iap_id: str, price: str) -> None:
    # An IAP is auto-assigned an (empty) price schedule on creation, so the
    # schedule resource always exists. The real question is whether it has any
    # manual prices — an empty schedule means no price has been set yet.
    prices = client.get_all(f"v1/inAppPurchasePriceSchedules/{iap_id}/manualPrices")
    if prices:
        print(f"  • price schedule already set")
        return
    point_id = find_price_point(client, iap_id, price)
    print(f"  + setting price ${price} (price point {point_id})")
    client.post("v1/inAppPurchasePriceSchedules", {
        "data": {
            "type": "inAppPurchasePriceSchedules",
            "relationships": {
                "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap_id}},
                "baseTerritory": {"data": {"type": "territories", "id": BASE_TERRITORY}},
                "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": "${price}"}]},
            },
        },
        "included": [{
            "type": "inAppPurchasePrices",
            "id": "${price}",
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
                        help="Print calls without making them.")
    parser.add_argument("--only", help="Comma-separated substrings; only matching "
                                        "product IDs are processed.")
    parser.add_argument("--skip-price", action="store_true",
                        help="Don't create price schedules (just IAP + localization + availability).")
    parser.add_argument("--skip-availability", action="store_true",
                        help="Don't create territory availability.")
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

    all_territories: list[str] = []
    if not args.skip_availability:
        all_territories = [t["id"] for t in client.get_all("v1/territories")]

    created = skipped = 0
    for product in products:
        print(f"{product['product_id']}  (${product['price']})")
        is_new = product["product_id"] not in existing
        iap_id = ensure_iap(client, app_id, product, existing)
        if iap_id is None:
            # dry-run create: nothing more we can do without a real id
            print("    [dry-run] skipping localization/availability/price for new IAP\n")
            created += 1
            continue
        ensure_localizations(client, iap_id, product)
        if not args.skip_availability:
            ensure_availability(client, iap_id, all_territories)
        if not args.skip_price:
            ensure_price(client, iap_id, product["price"])
        created += int(is_new)
        skipped += int(not is_new)
        print()

    print(f"Done. {created} created, {skipped} already existed.")
    print("\nNote: IAPs still need a review screenshot before you can submit them — "
          "add one per IAP in App Store Connect (or they'll sit in 'Missing Metadata').")


if __name__ == "__main__":
    main()
