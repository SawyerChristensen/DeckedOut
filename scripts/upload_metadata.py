#!/usr/bin/env python3
"""Upload App Store Connect and Game Center localizations for DeckedOut.

Reads scripts/metadata.json and pushes every filled locale to App Store Connect.
Locales set to null are skipped — fill them in first (ask Claude Code, or pass
--translate to call the Anthropic API directly).

Usage:
    python upload_metadata.py                   # upload what's in metadata.json
    python upload_metadata.py --dry-run         # show what would be uploaded
    python upload_metadata.py --version 1.2.0   # target a specific App Store version
    python upload_metadata.py --translate       # auto-fill missing locales via Claude API first
    python upload_metadata.py --translate-only  # fill JSON via Claude API, don't upload

Requires env vars (load from ~/.appstoreconnect/config.env or your shell):
    ASC_KEY_ID         App Store Connect API key ID (10-char string)
    ASC_ISSUER_ID      App Store Connect issuer ID (UUID)
    ASC_KEY_PATH       Path to the .p8 private key file
    ANTHROPIC_API_KEY  Only required if you pass --translate or --translate-only
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path
from typing import Any

import jwt
import requests

SCRIPT_DIR = Path(__file__).resolve().parent
METADATA_PATH = SCRIPT_DIR / "metadata.json"
ASC_BASE = "https://api.appstoreconnect.apple.com/v1"

# Xcode locale → App Store Connect locale. Game Center uses the same codes.
LOCALE_MAP: dict[str, str] = {
    "en": "en-US",
    "da": "da",
    "de": "de-DE",
    "es": "es-ES",
    "fr": "fr-FR",
    "hi": "hi",
    "it": "it",
    "ja": "ja",
    "ko": "ko",
    "nb": "no",
    "nl": "nl-NL",
    "pt-BR": "pt-BR",
    "ru": "ru",
    "sv": "sv",
    "tr": "tr",
    "vi": "vi",
    "zh-Hans": "zh-Hans",
    "zh-Hant": "zh-Hant",
}

LANGUAGE_NAMES: dict[str, str] = {
    "da": "Danish",
    "de": "German",
    "es": "Spanish (Spain)",
    "fr": "French (France)",
    "hi": "Hindi",
    "it": "Italian",
    "ja": "Japanese",
    "ko": "Korean",
    "nb": "Norwegian Bokmål",
    "nl": "Dutch",
    "pt-BR": "Brazilian Portuguese",
    "ru": "Russian",
    "sv": "Swedish",
    "tr": "Turkish",
    "vi": "Vietnamese",
    "zh-Hans": "Simplified Chinese",
    "zh-Hant": "Traditional Chinese",
}

# Map our JSON keys → App Store Connect attribute names.
VERSION_ATTR_MAP = {
    "whats_new": "whatsNew",
    "description": "description",
    "keywords": "keywords",
    "promotional_text": "promotionalText",
}
ACHIEVEMENT_ATTR_MAP = {
    "title": "name",  # NOTE: gameCenterAchievementLocalizations uses "name"
    "before_earned_description": "beforeEarnedDescription",
    "after_earned_description": "afterEarnedDescription",
}


# ---------- Translation via Claude ----------

def collect_missing(metadata: dict) -> list[tuple[list[str], str, str, int, str]]:
    """Walk metadata, return list of (path, english, tone, max_chars, locale) tuples
    for every locale that is null."""
    out = []
    locales = [loc for loc in metadata["_meta"]["locales"] if loc != "en"]

    def walk(node: dict, path: list[str]) -> None:
        if "en" in node and isinstance(node["en"], str):
            english = node["en"]
            tone = node.get("_tone", "")
            max_chars = node.get("_max_chars", 4000)
            for loc in locales:
                if node.get(loc) is None:
                    out.append((path, english, tone, max_chars, loc))
            return
        for key, val in node.items():
            if key.startswith("_") or not isinstance(val, dict):
                continue
            walk(val, path + [key])

    walk(metadata["version_localizations"], ["version_localizations"])
    walk(metadata["achievements"], ["achievements"])
    return out


def translate_field(client, english: str, tone: str, max_chars: int,
                    locales: list[str]) -> dict[str, str]:
    """Translate one English string into all given locales in a single Claude call."""
    schema = {
        "type": "object",
        "properties": {loc: {"type": "string"} for loc in locales},
        "required": locales,
        "additionalProperties": False,
    }
    locale_list = "\n".join(f"  - {loc}: {LANGUAGE_NAMES[loc]}" for loc in locales)
    system = (
        "You are a professional localizer for App Store and Game Center metadata. "
        "Translate the English text into each target locale.\n\n"
        f"CRITICAL CONSTRAINTS:\n"
        f"- Maximum {max_chars} characters per translation. Hard limit.\n"
        f"- Match the source tone, register, and formatting (line breaks, bullet "
        f"points, punctuation).\n"
        f"- Tone guidance: {tone}\n"
        "- Preserve game names ('Gin Rummy', 'Crazy 8s', 'Golf') unless the locale "
        "has a culturally established translation.\n"
        "- For keywords (comma-separated), translate each term and keep it comma-"
        "separated with no spaces after commas.\n"
        "- Do not add explanatory text. Return only the translation."
    )
    user = f"Source (English):\n{english}\n\nTarget locales:\n{locale_list}"
    response = client.messages.create(
        model="claude-opus-4-7",
        max_tokens=4096,
        system=system,
        messages=[{"role": "user", "content": user}],
        output_config={"format": {"type": "json_schema", "schema": schema}},
    )
    text = next(b.text for b in response.content if b.type == "text")
    return json.loads(text)


def fill_translations(metadata: dict) -> int:
    """Translate every missing locale via Claude. Returns number of translations made."""
    missing = collect_missing(metadata)
    if not missing:
        print("All translations already filled. Skipping Claude.")
        return 0

    try:
        import anthropic
    except ImportError:
        sys.exit("anthropic package not installed. pip install anthropic")

    client = anthropic.Anthropic()
    # Group by (english, tone, max_chars) so each unique source string is
    # translated in a single multi-locale call.
    groups: dict[tuple[str, str, int], list[tuple[list[str], str]]] = {}
    for path, english, tone, max_chars, loc in missing:
        groups.setdefault((english, tone, max_chars), []).append((path, loc))

    print(f"Translating {len(missing)} entries across {len(groups)} source strings...")
    count = 0
    for (english, tone, max_chars), entries in groups.items():
        locales = sorted({loc for _, loc in entries})
        preview = english.replace("\n", " ")[:60]
        print(f"  [{len(locales)} locales] {preview!r}")
        translations = translate_field(client, english, tone, max_chars, locales)
        for path, loc in entries:
            node = metadata
            for key in path:
                node = node[key]
            translation = translations[loc]
            if len(translation) > max_chars:
                print(f"    ⚠ {loc} exceeds {max_chars} chars ({len(translation)}), truncating")
                translation = translation[:max_chars]
            node[loc] = translation
            count += 1
    return count


# ---------- App Store Connect API ----------

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


def require_env(name: str) -> str:
    val = os.environ.get(name)
    if not val:
        sys.exit(f"Missing required env var: {name}")
    return val


class ASCClient:
    def __init__(self, dry_run: bool = False) -> None:
        self.token = make_jwt()
        self.headers = {
            "Authorization": f"Bearer {self.token}",
            "Content-Type": "application/json",
        }
        self.dry_run = dry_run
        self.session = requests.Session()

    def get(self, url: str, params: dict | None = None) -> dict:
        if not url.startswith("http"):
            url = f"{ASC_BASE}/{url.lstrip('/')}"
        r = self.session.get(url, headers=self.headers, params=params, timeout=30)
        if not r.ok:
            sys.exit(f"GET {url} failed ({r.status_code}): {r.text}")
        return r.json()

    def patch(self, path: str, body: dict) -> dict:
        url = f"{ASC_BASE}/{path.lstrip('/')}"
        if self.dry_run:
            print(f"    [dry-run] PATCH {path}")
            return {}
        r = self.session.patch(url, headers=self.headers, json=body, timeout=30)
        if not r.ok:
            sys.exit(f"PATCH {path} failed ({r.status_code}): {r.text}")
        return r.json()

    def post(self, path: str, body: dict) -> dict:
        url = f"{ASC_BASE}/{path.lstrip('/')}"
        if self.dry_run:
            print(f"    [dry-run] POST {path}")
            return {"data": {"id": "dry-run-id"}}
        r = self.session.post(url, headers=self.headers, json=body, timeout=30)
        if not r.ok:
            sys.exit(f"POST {path} failed ({r.status_code}): {r.text}")
        return r.json()


def find_app_id(client: ASCClient, bundle_id: str) -> str:
    data = client.get("apps", params={"filter[bundleId]": bundle_id})["data"]
    if not data:
        sys.exit(f"No app found with bundle ID {bundle_id}")
    return data[0]["id"]


def find_editable_version(client: ASCClient, app_id: str,
                          version_string: str | None) -> str:
    """Find a version that's still editable (whatsNew etc. can be changed)."""
    editable_states = {
        "PREPARE_FOR_SUBMISSION", "WAITING_FOR_REVIEW", "METADATA_REJECTED",
        "REJECTED", "DEVELOPER_REJECTED", "INVALID_BINARY",
        "DEVELOPER_REMOVED_FROM_SALE", "REPLACED_WITH_NEW_VERSION",
    }
    data = client.get(f"apps/{app_id}/appStoreVersions",
                      params={"limit": 20})["data"]
    for v in data:
        attrs = v["attributes"]
        if version_string and attrs["versionString"] != version_string:
            continue
        if attrs["appStoreState"] in editable_states:
            print(f"  Using version {attrs['versionString']} (state: {attrs['appStoreState']})")
            return v["id"]
    sys.exit("No editable App Store version found. Create one in App Store Connect first.")


def find_previous_version_localizations(client: ASCClient, app_id: str,
                                        current_version_id: str) -> dict[str, dict]:
    """Return {asc_locale: {asc_attr: value}} from the most recent prior version
    that has localization data. Used to inherit description, keywords, etc."""
    data = client.get(f"apps/{app_id}/appStoreVersions",
                      params={"limit": 20})["data"]
    # Apple returns newest first, but be explicit
    versions = sorted(data, key=lambda v: v["attributes"].get("createdDate", ""), reverse=True)
    for v in versions:
        if v["id"] == current_version_id:
            continue
        locs = client.get(
            f"appStoreVersions/{v['id']}/appStoreVersionLocalizations",
            params={"limit": 50},
        )["data"]
        if not locs:
            continue
        print(f"  Inheriting from version {v['attributes']['versionString']} "
              f"(state: {v['attributes']['appStoreState']})")
        return {loc["attributes"]["locale"]: loc["attributes"] for loc in locs}
    print("  No prior version found — no inheritance available.")
    return {}


def upload_version_localizations(client: ASCClient, app_id: str, version_id: str,
                                 metadata: dict) -> None:
    """PATCH whatsNew (from metadata.json) and inherit everything else
    (description, keywords, promotionalText) from the most recent prior version
    unless metadata.json explicitly overrides."""
    existing = client.get(f"appStoreVersions/{version_id}/appStoreVersionLocalizations",
                          params={"limit": 50})["data"]
    by_locale = {loc["attributes"]["locale"]: loc["id"] for loc in existing}
    current_attrs = {loc["attributes"]["locale"]: loc["attributes"] for loc in existing}

    previous_attrs = find_previous_version_localizations(client, app_id, version_id)

    locales = [loc for loc in metadata["_meta"]["locales"]]
    vloc = metadata["version_localizations"]

    for xcode_loc in locales:
        asc_loc = LOCALE_MAP[xcode_loc]
        attributes = {}
        sources: list[str] = []
        for json_key, asc_attr in VERSION_ATTR_MAP.items():
            override = vloc[json_key].get(xcode_loc)
            if override:
                attributes[asc_attr] = override
                sources.append(f"{asc_attr}=metadata")
            elif json_key == "whats_new":
                # Never inherit whatsNew — it's release-specific.
                continue
            else:
                inherited = previous_attrs.get(asc_loc, {}).get(asc_attr)
                # Only push if not already identical in the current version
                if inherited and current_attrs.get(asc_loc, {}).get(asc_attr) != inherited:
                    attributes[asc_attr] = inherited
                    sources.append(f"{asc_attr}=inherited")
        if not attributes:
            continue

        if asc_loc in by_locale:
            loc_id = by_locale[asc_loc]
            print(f"  [{asc_loc}] updating: {', '.join(sources)}")
            client.patch(f"appStoreVersionLocalizations/{loc_id}", {
                "data": {
                    "type": "appStoreVersionLocalizations",
                    "id": loc_id,
                    "attributes": attributes,
                }
            })
        else:
            print(f"  [{asc_loc}] creating: {', '.join(sources)}")
            attributes["locale"] = asc_loc
            client.post("appStoreVersionLocalizations", {
                "data": {
                    "type": "appStoreVersionLocalizations",
                    "attributes": attributes,
                    "relationships": {
                        "appStoreVersion": {
                            "data": {"type": "appStoreVersions", "id": version_id}
                        }
                    },
                }
            })


def resolve_image_path(image_field: str | None) -> Path | None:
    """Resolve an _default_image path relative to scripts/. None if missing."""
    if not image_field:
        return None
    path = Path(image_field).expanduser()
    if not path.is_absolute():
        path = SCRIPT_DIR / path
    if not path.exists():
        sys.exit(f"Image file not found: {path}")
    return path


def upload_achievement_image(client: ASCClient, loc_id: str, image_path: Path) -> None:
    """Upload an image and attach it to a gameCenterAchievementLocalization."""
    if client.dry_run:
        print(f"    [dry-run] upload image {image_path.name}")
        return

    image_bytes = image_path.read_bytes()
    # 1. Reserve an upload slot
    resp = client.post("gameCenterAchievementImages", {
        "data": {
            "type": "gameCenterAchievementImages",
            "attributes": {
                "fileSize": len(image_bytes),
                "fileName": image_path.name,
            },
            "relationships": {
                "gameCenterAchievementLocalization": {
                    "data": {
                        "type": "gameCenterAchievementLocalizations",
                        "id": loc_id,
                    }
                }
            },
        }
    })
    img_id = resp["data"]["id"]
    upload_operations = resp["data"]["attributes"]["uploadOperations"]

    # 2. PUT bytes to each upload operation
    for op in upload_operations:
        headers = {h["name"]: h["value"] for h in op["requestHeaders"]}
        chunk = image_bytes[op["offset"]:op["offset"] + op["length"]]
        r = requests.put(op["url"], headers=headers, data=chunk, timeout=60)
        if not r.ok:
            sys.exit(f"Image upload PUT failed ({r.status_code}): {r.text}")

    # 3. Mark as uploaded
    client.patch(f"gameCenterAchievementImages/{img_id}", {
        "data": {
            "type": "gameCenterAchievementImages",
            "id": img_id,
            "attributes": {"uploaded": True},
        }
    })


def upload_achievements(client: ASCClient, app_id: str, metadata: dict) -> None:
    """Update Game Center achievement localizations."""
    detail = client.get(f"apps/{app_id}/gameCenterDetail")["data"]
    detail_id = detail["id"]

    achievements_resp = client.get(
        f"gameCenterDetails/{detail_id}/gameCenterAchievements",
        params={"limit": 200},
    )
    achievements_by_ref = {a["attributes"]["referenceName"]: a for a in achievements_resp["data"]}
    achievements_by_vendor = {a["attributes"]["vendorIdentifier"]: a for a in achievements_resp["data"]}

    for ach_id, ach_meta in metadata["achievements"].items():
        ach = achievements_by_vendor.get(ach_id) or achievements_by_ref.get(ach_id)
        if not ach:
            print(f"  ⚠ Achievement '{ach_id}' not found in App Store Connect. "
                  f"Create it first (under Game Center > Achievements).")
            continue
        ach_apple_id = ach["id"]
        image_path = resolve_image_path(ach_meta.get("_default_image"))
        print(f"\nAchievement: {ach_id}")

        existing = client.get(
            f"gameCenterAchievements/{ach_apple_id}/localizations",
            params={"limit": 50},
        )["data"]
        by_locale = {loc["attributes"]["locale"]: loc["id"] for loc in existing}

        for xcode_loc in metadata["_meta"]["locales"]:
            asc_loc = LOCALE_MAP[xcode_loc]
            attributes = {}
            for json_key, asc_attr in ACHIEVEMENT_ATTR_MAP.items():
                val = ach_meta[json_key].get(xcode_loc)
                if val:
                    attributes[asc_attr] = val
            if not attributes:
                continue

            if asc_loc in by_locale:
                loc_id = by_locale[asc_loc]
                print(f"  [{asc_loc}] updating")
                client.patch(f"gameCenterAchievementLocalizations/{loc_id}", {
                    "data": {
                        "type": "gameCenterAchievementLocalizations",
                        "id": loc_id,
                        "attributes": attributes,
                    }
                })
            else:
                if not image_path:
                    print(f"  [{asc_loc}] missing and no _default_image set for "
                          f"'{ach_id}'. Add an image path to metadata.json or create "
                          f"this locale manually in App Store Connect. Skipping.")
                    continue
                print(f"  [{asc_loc}] creating with image {image_path.name}")
                attributes["locale"] = asc_loc
                resp = client.post("gameCenterAchievementLocalizations", {
                    "data": {
                        "type": "gameCenterAchievementLocalizations",
                        "attributes": attributes,
                        "relationships": {
                            "gameCenterAchievement": {
                                "data": {
                                    "type": "gameCenterAchievements",
                                    "id": ach_apple_id,
                                }
                            }
                        },
                    }
                })
                new_loc_id = resp["data"]["id"]
                upload_achievement_image(client, new_loc_id, image_path)


# ---------- Main ----------

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--translate", action="store_true",
                        help="Auto-fill missing locales via Claude API before uploading.")
    parser.add_argument("--translate-only", action="store_true",
                        help="Auto-fill missing locales via Claude API and exit (no upload).")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print upload calls without making them.")
    parser.add_argument("--version", help="Target a specific App Store version string.")
    parser.add_argument("--skip-version", action="store_true",
                        help="Skip App Store version metadata (only do Game Center).")
    parser.add_argument("--skip-achievements", action="store_true",
                        help="Skip Game Center achievements (only do version metadata).")
    args = parser.parse_args()

    metadata = json.loads(METADATA_PATH.read_text())

    if args.translate or args.translate_only:
        n = fill_translations(metadata)
        if n:
            METADATA_PATH.write_text(json.dumps(metadata, indent=2, ensure_ascii=False) + "\n")
            print(f"Wrote {n} translations back to {METADATA_PATH.name}")

    if args.translate_only:
        return

    client = ASCClient(dry_run=args.dry_run)
    bundle_id = metadata["_meta"]["bundle_id"]
    print(f"\nLooking up app {bundle_id}...")
    app_id = find_app_id(client, bundle_id)

    if not args.skip_version:
        print("\n=== App Store version localizations ===")
        version_id = find_editable_version(client, app_id, args.version)
        upload_version_localizations(client, app_id, version_id, metadata)

    if not args.skip_achievements:
        print("\n=== Game Center achievements ===")
        upload_achievements(client, app_id, metadata)

    print("\nDone.")


if __name__ == "__main__":
    main()
