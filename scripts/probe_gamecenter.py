#!/usr/bin/env python3
"""Read-only probe of the Game Center topology in App Store Connect.

Answers the one question that decides whether Game Center can ever work from the
iMessage extension: can the extension's code-signed bundle id be enrolled in a
Game Center *group* shared with the parent app?

GameKit identifies the running game by the extension's real, code-signed bundle id
(Sawyer.DeckedOut.MessagesExtension). That id has no Game Center record of its own —
the achievements live under the parent app (Sawyer.DeckedOut). The only Apple-
supported way to make the extension's id resolve to those same achievements is a
Game Center group containing BOTH bundle ids, addressed via grp.-prefixed ids.

For that to be possible, each bundle id needs an App Store Connect `app` record
with a `gameCenterDetail` that a `gameCenterGroup` can link. This probe checks:

  1. Does an ASC app record exist for the parent id?     (expected: yes)
  2. Does an ASC app record exist for the extension id?  (the crux — usually no,
     because an embedded .appex is not its own distributable App Store product)
  3. Is there already a Game Center group, and which bundle ids are in it?
  4. Are the parent's achievement identifiers already grp.-prefixed?
  5. At the Developer-portal identifier level, does the extension's bundle id have
     the GAME_CENTER capability enabled?

Makes ONLY GET requests — never writes. Exit code is always 0; this is a report.

Usage:
    python probe_gamecenter.py
    python probe_gamecenter.py --json     # raw findings as JSON

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

PARENT_BUNDLE_ID = "Sawyer.DeckedOut"
EXTENSION_BUNDLE_ID = "Sawyer.DeckedOut.MessagesExtension"


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
    """A GET-only App Store Connect client with token auto-refresh.

    There is deliberately no patch/post/delete. get() returns None on a 404 so
    callers can treat "record does not exist" as a finding rather than an error.
    """

    TOKEN_TTL = 15 * 60

    def __init__(self) -> None:
        self.session = requests.Session()
        self._refresh()

    def _refresh(self) -> None:
        self.headers = {"Authorization": f"Bearer {make_jwt()}"}
        self.minted_at = time.time()

    def get(self, url: str, params: dict | None = None) -> dict | None:
        if not url.startswith("http"):
            url = f"{ASC_BASE}/{url.lstrip('/')}"
        for attempt in range(1, 6):
            if time.time() - self.minted_at >= self.TOKEN_TTL:
                self._refresh()
            r = self.session.get(url, headers=self.headers, params=params, timeout=60)
            if r.ok:
                return r.json()
            if r.status_code == 404:
                return None
            if r.status_code in (429, 500, 502, 503, 504) and attempt < 5:
                time.sleep(2 ** attempt)
                continue
            sys.exit(f"GET {url} failed ({r.status_code}): {r.text}")
        sys.exit(f"GET {url} failed after retries")


def find_app(client: ReadOnlyClient, bundle_id: str) -> dict | None:
    resp = client.get("apps", params={"filter[bundleId]": bundle_id})
    data = (resp or {}).get("data") or []
    return data[0] if data else None


def game_center_detail(client: ReadOnlyClient, app_id: str) -> dict | None:
    # include the group so we learn group membership in one call.
    resp = client.get(f"apps/{app_id}/gameCenterDetail",
                      params={"include": "gameCenterGroup"})
    if not resp:
        return None
    return resp


def achievements(client: ReadOnlyClient, detail_id: str) -> list[dict]:
    resp = client.get(f"gameCenterDetails/{detail_id}/gameCenterAchievements",
                      params={"limit": 200})
    return (resp or {}).get("data") or []


def group_members(client: ReadOnlyClient, group_id: str) -> list[str]:
    """Return the bundle ids of every app whose gameCenterDetail is in the group."""
    resp = client.get(f"gameCenterGroups/{group_id}/gameCenterDetails",
                      params={"include": "app", "limit": 50})
    if not resp:
        return []
    apps_by_id = {a["id"]: a for a in resp.get("included", []) if a["type"] == "apps"}
    out = []
    for detail in resp.get("data", []):
        app_ref = (detail.get("relationships", {}).get("app", {}) or {}).get("data")
        if app_ref and app_ref["id"] in apps_by_id:
            out.append(apps_by_id[app_ref["id"]]["attributes"].get("bundleId", app_ref["id"]))
        else:
            out.append(f"(detail {detail['id']}, app not included)")
    return out


def bundle_id_capabilities(client: ReadOnlyClient, identifier: str) -> dict | None:
    """Developer-portal identifier record + its enabled capabilities."""
    resp = client.get("bundleIds", params={
        "filter[identifier]": identifier,
        "include": "bundleIdCapabilities",
        "limit": 1,
    })
    if not resp or not resp.get("data"):
        return None
    record = resp["data"][0]
    caps = [c["attributes"].get("capabilityType")
            for c in resp.get("included", []) if c["type"] == "bundleIdCapabilities"]
    return {"id": record["id"],
            "name": record["attributes"].get("name"),
            "capabilities": sorted(c for c in caps if c)}


def probe(client: ReadOnlyClient) -> dict:
    findings: dict = {"parent": {}, "extension": {}, "group": None, "verdict": None}

    # --- Parent app ---
    parent_app = find_app(client, PARENT_BUNDLE_ID)
    findings["parent"]["app_record_exists"] = parent_app is not None
    group_id = None
    if parent_app:
        pid = parent_app["id"]
        findings["parent"]["app_id"] = pid
        detail = game_center_detail(client, pid)
        if detail and detail.get("data"):
            did = detail["data"]["id"]
            findings["parent"]["game_center_detail_id"] = did
            grp = (detail["data"].get("relationships", {})
                   .get("gameCenterGroup", {}) or {}).get("data")
            group_id = grp["id"] if grp else None
            findings["parent"]["in_group"] = group_id is not None
            achs = achievements(client, did)
            ids = [a["attributes"].get("vendorIdentifier") for a in achs]
            findings["parent"]["achievement_count"] = len(ids)
            findings["parent"]["achievement_ids_sample"] = ids[:6]
            findings["parent"]["all_grp_prefixed"] = bool(ids) and all(
                (i or "").startswith("grp.") for i in ids)
        else:
            findings["parent"]["game_center_detail_id"] = None
            findings["parent"]["in_group"] = False

    # --- Extension app ---
    ext_app = find_app(client, EXTENSION_BUNDLE_ID)
    findings["extension"]["app_record_exists"] = ext_app is not None
    if ext_app:
        eid = ext_app["id"]
        findings["extension"]["app_id"] = eid
        ext_detail = game_center_detail(client, eid)
        findings["extension"]["has_game_center_detail"] = bool(
            ext_detail and ext_detail.get("data"))
        if ext_detail and ext_detail.get("data"):
            egrp = (ext_detail["data"].get("relationships", {})
                    .get("gameCenterGroup", {}) or {}).get("data")
            if egrp:
                group_id = group_id or egrp["id"]
                findings["extension"]["in_group"] = True

    # Developer-portal identifier capabilities for the extension.
    findings["extension"]["identifier_record"] = bundle_id_capabilities(
        client, EXTENSION_BUNDLE_ID)

    # --- Group membership ---
    if group_id:
        findings["group"] = {
            "id": group_id,
            "member_bundle_ids": group_members(client, group_id),
        }

    # --- Verdict ---
    ext_exists = findings["extension"]["app_record_exists"]
    in_group_together = bool(
        findings["group"]
        and PARENT_BUNDLE_ID in (findings["group"]["member_bundle_ids"] or [])
        and EXTENSION_BUNDLE_ID in (findings["group"]["member_bundle_ids"] or []))

    if in_group_together:
        verdict = ("READY: both bundle ids are already in a Game Center group. "
                   "Migrate the Achievement enum + metadata.json to the grp.-prefixed "
                   "identifiers and reporting from the extension should resolve.")
    elif ext_exists:
        verdict = ("FEASIBLE: the extension bundle id has its own ASC app record, so it "
                   "can be given a gameCenterDetail and added to a group with the parent. "
                   "Create/confirm the group, add both, migrate to grp. ids.")
    else:
        verdict = ("BLOCKED at ASC: no App Store Connect *app* record exists for the "
                   "extension bundle id (it ships embedded, not as its own product), so "
                   "there is nothing for a Game Center group to link. Game Center cannot "
                   "recognize the extension's id through grouping until that is resolved — "
                   "this is the question to take to Apple Developer Support / a TSI. "
                   "Check the 'identifier_record' field: if the GAME_CENTER capability is "
                   "present on the bundle id but no app record exists, that mismatch is the "
                   "crux to cite.")
    findings["verdict"] = verdict
    return findings


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true",
                        help="Dump raw findings as JSON.")
    args = parser.parse_args()

    load_config()
    client = ReadOnlyClient()
    print(f"Probing Game Center topology for {PARENT_BUNDLE_ID} "
          f"and {EXTENSION_BUNDLE_ID}...\n", file=sys.stderr)
    findings = probe(client)

    if args.json:
        print(json.dumps(findings, indent=2))
        return

    p, e, g = findings["parent"], findings["extension"], findings["group"]
    print("=== Parent app (achievements live here) ===")
    print(f"  bundle id:            {PARENT_BUNDLE_ID}")
    print(f"  ASC app record:       {'yes' if p.get('app_record_exists') else 'NO'}")
    print(f"  gameCenterDetail:     {p.get('game_center_detail_id') or 'none'}")
    print(f"  in a group:           {p.get('in_group')}")
    print(f"  achievements:         {p.get('achievement_count', 0)}")
    print(f"  ids already grp.:     {p.get('all_grp_prefixed')}")
    if p.get("achievement_ids_sample"):
        print(f"  sample ids:           {', '.join(p['achievement_ids_sample'])}")

    print("\n=== Extension app (what GameKit actually runs as) ===")
    print(f"  bundle id:            {EXTENSION_BUNDLE_ID}")
    print(f"  ASC app record:       {'yes' if e.get('app_record_exists') else 'NO  <-- the crux'}")
    print(f"  gameCenterDetail:     {e.get('has_game_center_detail')}")
    rec = e.get("identifier_record")
    if rec:
        caps = ", ".join(rec["capabilities"]) or "(none)"
        print(f"  identifier record:    {rec['name']} — capabilities: {caps}")
    else:
        print("  identifier record:    not found via API")

    print("\n=== Game Center group ===")
    if g:
        print(f"  group id:             {g['id']}")
        print(f"  member bundle ids:    {', '.join(g['member_bundle_ids']) or '(none)'}")
    else:
        print("  no group found")

    print("\n=== Verdict ===")
    print(f"  {findings['verdict']}")


if __name__ == "__main__":
    main()
