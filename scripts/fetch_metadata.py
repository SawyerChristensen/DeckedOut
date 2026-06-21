#!/usr/bin/env python3
"""Read-only dump of live App Store version metadata for DeckedOut.

Fetches keywords, description, and promotional text for every App Store version
and every locale straight from App Store Connect. Makes ONLY GET requests — it
never writes anything. Use it to compare what shipped with 3.4 vs 3.3 and see
whether your search keywords actually changed.

Usage:
    python fetch_metadata.py                       # dump keywords for all versions
    python fetch_metadata.py --fields all          # keywords + description + promo
    python fetch_metadata.py --versions 3.4.0 3.3.0  # only these version strings
    python fetch_metadata.py --diff 3.4.0 3.3.0    # show only locales that differ
    python fetch_metadata.py --json                # machine-readable output

Reuses the same credentials as upload_metadata.py (loaded from
~/.appstoreconnect/config.env or scripts/.env, or the environment):
    ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH
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
METADATA_PATH = SCRIPT_DIR / "metadata.json"
ASC_BASE = "https://api.appstoreconnect.apple.com/v1"

CONFIG_PATHS = [
    Path("~/.appstoreconnect/config.env").expanduser(),
    SCRIPT_DIR / ".env",
]

# The search-relevant fields, in display order.
FIELD_ATTRS = {
    "keywords": "keywords",
    "description": "description",
    "promo": "promotionalText",
    "whatsNew": "whatsNew",
}


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
        "exp": now + 20 * 60,
        "aud": "appstoreconnect-v1",
    }
    return jwt.encode(payload, private_key, algorithm="ES256",
                      headers={"kid": key_id, "typ": "JWT"})


class ReadOnlyClient:
    """A GET-only App Store Connect client. There is deliberately no patch/post."""

    def __init__(self) -> None:
        self.headers = {"Authorization": f"Bearer {make_jwt()}"}
        self.session = requests.Session()

    def get(self, url: str, params: dict | None = None) -> dict:
        if not url.startswith("http"):
            url = f"{ASC_BASE}/{url.lstrip('/')}"
        max_attempts = 5
        for attempt in range(1, max_attempts + 1):
            r = self.session.request("GET", url, headers=self.headers,
                                     params=params, timeout=60)
            if r.ok:
                return r.json()
            if r.status_code in (429, 500, 502, 503, 504) and attempt < max_attempts:
                wait = 2 ** attempt
                print(f"  ⚠ GET {url} -> {r.status_code}, retrying in {wait}s",
                      file=sys.stderr)
                time.sleep(wait)
                continue
            sys.exit(f"GET {url} failed ({r.status_code}): {r.text}")
        sys.exit(f"GET {url} failed after {max_attempts} attempts")


def find_app_id(client: ReadOnlyClient, bundle_id: str) -> str:
    data = client.get("apps", params={"filter[bundleId]": bundle_id})["data"]
    if not data:
        sys.exit(f"No app found with bundle ID {bundle_id}")
    return data[0]["id"]


def fetch_versions(client: ReadOnlyClient, app_id: str) -> list[dict]:
    """Return versions newest-first, each with its per-locale attributes attached."""
    data = client.get(f"apps/{app_id}/appStoreVersions", params={"limit": 50})["data"]
    versions = sorted(data, key=lambda v: v["attributes"].get("createdDate", ""),
                      reverse=True)
    out = []
    for v in versions:
        locs = client.get(
            f"appStoreVersions/{v['id']}/appStoreVersionLocalizations",
            params={"limit": 50},
        )["data"]
        out.append({
            "version": v["attributes"]["versionString"],
            "state": v["attributes"]["appStoreState"],
            "created": v["attributes"].get("createdDate", ""),
            "locales": {loc["attributes"]["locale"]: loc["attributes"] for loc in locs},
        })
    return out


def print_version(ver: dict, fields: list[str]) -> None:
    print(f"\n=== {ver['version']}  (state: {ver['state']}, created: {ver['created'][:10]}) ===")
    for locale in sorted(ver["locales"]):
        attrs = ver["locales"][locale]
        print(f"  {locale}")
        for field in fields:
            value = attrs.get(FIELD_ATTRS[field]) or ""
            preview = value.replace("\n", " ⏎ ")
            print(f"    {field:11} ({len(value):>4}): {preview}")


def print_diff(a: dict, b: dict, fields: list[str]) -> None:
    """Show only locale/field pairs where version a differs from version b."""
    print(f"\n=== diff: {a['version']} vs {b['version']} (only differences) ===")
    all_locales = sorted(set(a["locales"]) | set(b["locales"]))
    any_diff = False
    for locale in all_locales:
        a_attrs = a["locales"].get(locale, {})
        b_attrs = b["locales"].get(locale, {})
        for field in fields:
            av = a_attrs.get(FIELD_ATTRS[field]) or ""
            bv = b_attrs.get(FIELD_ATTRS[field]) or ""
            if av != bv:
                any_diff = True
                print(f"  {locale} / {field}")
                print(f"    {a['version']}: {av.replace(chr(10), ' ⏎ ')}")
                print(f"    {b['version']}: {bv.replace(chr(10), ' ⏎ ')}")
    if not any_diff:
        print("  (identical across the requested fields)")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fields", default="keywords",
                        choices=["keywords", "search", "all"],
                        help="keywords (default), search (keywords+description+promo), "
                             "or all (adds whatsNew).")
    parser.add_argument("--versions", nargs="*",
                        help="Limit to these version strings (e.g. 3.4.0 3.3.0).")
    parser.add_argument("--diff", nargs=2, metavar=("A", "B"),
                        help="Show only fields that differ between two version strings.")
    parser.add_argument("--json", action="store_true",
                        help="Dump raw fetched data as JSON instead of a report.")
    args = parser.parse_args()

    if args.fields == "keywords":
        fields = ["keywords"]
    elif args.fields == "search":
        fields = ["keywords", "description", "promo"]
    else:
        fields = ["keywords", "description", "promo", "whatsNew"]

    load_config()
    bundle_id = json.loads(METADATA_PATH.read_text())["_meta"]["bundle_id"]

    client = ReadOnlyClient()
    print(f"Looking up app {bundle_id}...", file=sys.stderr)
    app_id = find_app_id(client, bundle_id)
    versions = fetch_versions(client, app_id)

    if args.json:
        print(json.dumps(versions, indent=2, ensure_ascii=False))
        return

    by_string = {v["version"]: v for v in versions}

    if args.diff:
        a_str, b_str = args.diff
        if a_str not in by_string or b_str not in by_string:
            available = ", ".join(sorted(by_string))
            sys.exit(f"Version not found. Available: {available}")
        print_diff(by_string[a_str], by_string[b_str], fields)
        return

    selected = versions
    if args.versions:
        selected = [v for v in versions if v["version"] in args.versions]
        if not selected:
            available = ", ".join(sorted(by_string))
            sys.exit(f"No matching versions. Available: {available}")

    for ver in selected:
        print_version(ver, fields)


if __name__ == "__main__":
    main()
