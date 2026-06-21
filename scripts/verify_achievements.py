#!/usr/bin/env python3
"""Read-only verification of Game Center achievement localizations in ASC.

Cross-checks what's live in App Store Connect against scripts/metadata.json for
every achievement and every locale. Makes ONLY GET requests — never writes.

Reports, per achievement:
  - which locales are present vs. missing
  - whether the live name / before / after text matches metadata.json
  - whether each localization's image finished uploading (COMPLETE)

Exits non-zero if anything is missing or mismatched, so it doubles as a check.

Usage:
    python verify_achievements.py            # full report
    python verify_achievements.py --quiet     # only show problems

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

# Xcode locale → App Store Connect locale (must match upload_metadata.py).
LOCALE_MAP = {
    "en": "en-US", "da": "da", "de": "de-DE", "es": "es-ES", "fr": "fr-FR",
    "hi": "hi", "it": "it", "ja": "ja", "ko": "ko", "nb": "no", "nl": "nl-NL",
    "pt-BR": "pt-BR", "ru": "ru", "sv": "sv", "tr": "tr", "vi": "vi",
    "zh-Hans": "zh-Hans", "zh-Hant": "zh-Hant",
}
ACHIEVEMENT_ATTR_MAP = {
    "title": "name",
    "before_earned_description": "beforeEarnedDescription",
    "after_earned_description": "afterEarnedDescription",
}


def load_config() -> None:
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
    payload = {"iss": issuer_id, "iat": now, "exp": now + 20 * 60,
               "aud": "appstoreconnect-v1"}
    return jwt.encode(payload, private_key, algorithm="ES256",
                      headers={"kid": key_id, "typ": "JWT"})


class ReadOnlyClient:
    """A GET-only App Store Connect client with token auto-refresh."""

    TOKEN_TTL = 15 * 60

    def __init__(self) -> None:
        self.session = requests.Session()
        self._refresh()

    def _refresh(self) -> None:
        self.headers = {"Authorization": f"Bearer {make_jwt()}"}
        self.minted_at = time.time()

    def get(self, url: str, params: dict | None = None) -> dict:
        if not url.startswith("http"):
            url = f"{ASC_BASE}/{url.lstrip('/')}"
        for attempt in range(1, 6):
            if time.time() - self.minted_at >= self.TOKEN_TTL:
                self._refresh()
            r = self.session.get(url, headers=self.headers, params=params, timeout=60)
            if r.ok:
                return r.json()
            if r.status_code in (429, 500, 502, 503, 504) and attempt < 5:
                time.sleep(2 ** attempt)
                continue
            sys.exit(f"GET {url} failed ({r.status_code}): {r.text}")
        sys.exit(f"GET {url} failed after retries")


def image_complete(img: dict | None) -> bool:
    if not img:
        return False
    attrs = img.get("attributes", {})
    if attrs.get("uploaded") is False:
        return False
    state = (attrs.get("assetDeliveryState") or {}).get("state")
    if state and state != "COMPLETE":
        return False
    return True


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--quiet", action="store_true",
                        help="Only print achievements with problems.")
    args = parser.parse_args()

    load_config()
    metadata = json.loads(METADATA_PATH.read_text())
    bundle_id = metadata["_meta"]["bundle_id"]
    xcode_locales = metadata["_meta"]["locales"]
    expected = {LOCALE_MAP[l] for l in xcode_locales}

    client = ReadOnlyClient()
    print(f"Looking up app {bundle_id}...", file=sys.stderr)
    app = client.get("apps", params={"filter[bundleId]": bundle_id})["data"]
    if not app:
        sys.exit(f"No app found with bundle ID {bundle_id}")
    app_id = app[0]["id"]
    detail_id = client.get(f"apps/{app_id}/gameCenterDetail")["data"]["id"]

    ach_resp = client.get(f"gameCenterDetails/{detail_id}/gameCenterAchievements",
                          params={"limit": 200})["data"]
    by_vendor = {a["attributes"]["vendorIdentifier"]: a for a in ach_resp}
    by_ref = {a["attributes"]["referenceName"]: a for a in ach_resp}

    total_problems = 0
    summary_lines = []

    for ach_id, ach_meta in metadata["achievements"].items():
        ach = by_vendor.get(ach_id) or by_ref.get(ach_id)
        if not ach:
            total_problems += 1
            summary_lines.append(f"  ✗ {ach_id:32} NOT FOUND in App Store Connect")
            continue

        locs = client.get(f"gameCenterAchievements/{ach['id']}/localizations",
                          params={"limit": 50})["data"]
        live = {l["attributes"]["locale"]: l for l in locs}
        present = set(live)

        problems = []
        missing = expected - present
        if missing:
            problems.append(f"missing locales: {', '.join(sorted(missing))}")
        extra = present - expected
        if extra:
            problems.append(f"unexpected locales: {', '.join(sorted(extra))}")

        # Per-locale text + image checks.
        text_mismatch = []
        img_bad = []
        for xcode_loc in xcode_locales:
            asc_loc = LOCALE_MAP[xcode_loc]
            loc = live.get(asc_loc)
            if not loc:
                continue
            attrs = loc["attributes"]
            for json_key, asc_attr in ACHIEVEMENT_ATTR_MAP.items():
                want = ach_meta[json_key].get(xcode_loc)
                got = attrs.get(asc_attr)
                if want and got != want:
                    text_mismatch.append(f"{asc_loc}/{asc_attr}")
            img = client.get(
                f"gameCenterAchievementLocalizations/{loc['id']}/gameCenterAchievementImage"
            ).get("data")
            if not image_complete(img):
                img_bad.append(asc_loc)
        if text_mismatch:
            problems.append(f"text mismatch: {', '.join(text_mismatch)}")
        if img_bad:
            problems.append(f"image incomplete/missing: {', '.join(sorted(img_bad))}")

        if problems:
            total_problems += len(problems)
            summary_lines.append(f"  ✗ {ach_id:32} {len(present)}/{len(expected)} locales")
            for p in problems:
                summary_lines.append(f"        - {p}")
        elif not args.quiet:
            summary_lines.append(f"  ✓ {ach_id:32} {len(present)}/{len(expected)} locales, "
                                 f"all text matches, all images complete")

    print("\n=== Game Center achievement verification ===")
    for line in summary_lines:
        print(line)

    if total_problems:
        print(f"\n{total_problems} problem(s) found.")
        sys.exit(1)
    print(f"\nAll {len(metadata['achievements'])} achievements fully localized "
          f"into {len(expected)} locales, with matching text and complete images. ✓")


if __name__ == "__main__":
    main()
