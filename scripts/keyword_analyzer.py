#!/usr/bin/env python3
"""Local ASO keyword competition analyzer for Card Games for iMessage.

No paid tools. Two data sources, both free:

  1. iTunes Search API (public, no auth) -> the competitor field for any
     keyword in any storefront: ratings, review counts, ages, publishers.
     This drives the DIFFICULTY score and the live rank check.

  2. RespectASO's already-synced SQLite cache of Apple's official
     "top search terms" popularity (Apple Search Ads data the user
     pulled with their own API key). Read-only. Covers us/gb/ca/au/de.
     For other storefronts POPULARITY is estimated and flagged.

Difficulty methodology mirrors what RespectASO exposes in its
`difficulty_breakdown` JSON: rating volume, dominant players, title
relevance, rating quality, market age, publisher concentration -> a
0-100 blend with Easy/Moderate/Hard/Very Hard/Extreme bands.

Usage:
    python keyword_analyzer.py --locale en                 # current en field
    python keyword_analyzer.py --locale en --candidates    # + mined candidates
    python keyword_analyzer.py --locale en-GB --countries gb,au,ca
    python keyword_analyzer.py --all                        # every locale in metadata.json
    python keyword_analyzer.py --locale en --report md      # markdown table to stdout
    python keyword_analyzer.py --locale en --offline        # only use cached iTunes data

Outputs land in scripts/keyword_analysis/<locale>/ (json + csv + md) and a
proposed <=100-char keyword field assembled from the winners.
"""
from __future__ import annotations

import argparse
import csv
import json
import math
import re
import sqlite3
import sys
import time
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
METADATA_PATH = SCRIPT_DIR / "metadata.json"
OUT_ROOT = SCRIPT_DIR / "keyword_analysis"
CACHE_DIR = OUT_ROOT / "_itunes_cache"
RESPECTASO_DB = Path(
    "~/Library/Application Support/RespectASO/db.sqlite3"
).expanduser()

OUR_TRACK_ID = 6757935828  # Card Games for iMessage

# metadata.json locale -> iTunes storefront country code
LOCALE_COUNTRY = {
    "en": "us", "en-GB": "gb", "da": "dk", "de": "de", "es": "es",
    "fi": "fi", "fr": "fr", "hi": "in", "it": "it", "ja": "jp", "ko": "kr",
    "nb": "no", "nl": "nl", "pl": "pl", "pt-BR": "br", "pt-PT": "pt",
    "ru": "ru", "sv": "se", "tr": "tr", "vi": "vn", "zh-Hans": "cn",
    "zh-Hant": "tw",
}

# The games this app actually contains. Keywords with no plausible match
# here get a relevance warning (they can hurt conversion + relevance).
APP_GAMES = {
    "gin", "rummy", "gin rummy", "eights", "eight", "8s", "crazy eights",
    "crazy 8s", "switch", "golf", "card", "cards", "card game", "card games",
}

# Extra candidate keywords to score alongside the current field.
# Curated for THIS app: Gin Rummy + Crazy 8s + Golf, async, iMessage, 2-player.
BASE_CANDIDATES = [
    # game-name variants not already in title/subtitle
    "crazy eights", "crazy 8", "eights", "gin", "rummy", "golf card game",
    "card golf",
    # iMessage / format angle
    "imessage games", "games for imessage", "message games", "text games",
    "play by text", "group chat games", "sticker games",
    # multiplayer / social angle
    "two player card", "2 player card", "multiplayer card",
    "card games with friends", "turn based card", "pass and play",
    "1v1 card game",
    # casual / couple angle
    "couple games", "games for couples", "long distance games",
    "date night games",
    # category
    "classic card games", "card game collection", "family card games",
    "card games offline",
]

# Unambiguous card/table-game phrases to harvest from Apple's GAMES
# top-terms list. Deliberately narrow - bare "card"/"golf"/"gin" pull in
# credit-card and golf-GPS apps, so they are not here.
_MINE_ALLOW = re.compile(
    r"\b(card game|card games|rummy|solitaire|poker|spades|hearts|euchre|"
    r"pinochle|canasta|cribbage|whist|blackjack|\buno\b|crazy eight|"
    r"crazy 8|two player game|2 player game|board game|board games)\b",
    re.I,
)
_MINE_BLOCK = re.compile(
    r"credit|debit|gift card|sim card|id card|scanner|value|ladder|clipper|"
    r"clash|royal|saga|tycoon|merge|roblox|minecraft", re.I,
)

# A candidate is only allowed into the assembled field if it is actually
# about this app: its games, or its format (async / iMessage / 2-player).
_RELEVANT = re.compile(
    r"\b(gin|rummy|eight|eights|8s?|golf|crazy|card|cards|deck|pigeon|"
    r"imessage|message|messages|text|texting|chat|sticker|stickers|"
    r"turn based|turn-based|async|pass and play|play by text|"
    r"two player|2 player|1v1|multiplayer|solo|offline|classic|"
    r"couple|couples|partner|long distance|date night|family|friend|friends)\b",
    re.I,
)

ITUNES_ENDPOINT = "https://itunes.apple.com/search"
TOP_N = 20            # ranked slots that matter for displacement
FETCH_LIMIT = 200     # apps to pull per query (max iTunes allows; better rank check)
SLEEP_BETWEEN = 1.6   # be polite to Apple


# --------------------------------------------------------------------------
# data acquisition
# --------------------------------------------------------------------------

def itunes_search(term: str, country: str, offline: bool = False) -> dict:
    """iTunes Search API with a 7-day disk cache."""
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    slug = re.sub(r"[^a-z0-9]+", "_", term.lower()).strip("_")
    stamp = datetime.now(timezone.utc).strftime("%Y%W")  # year+week
    cache = CACHE_DIR / f"{country}__{slug}__{stamp}.json"
    if cache.exists():
        return json.loads(cache.read_text())
    # fall back to the most recent older cache file for this term/country
    if offline:
        olds = sorted(CACHE_DIR.glob(f"{country}__{slug}__*.json"))
        if olds:
            return json.loads(olds[-1].read_text())
        return {"resultCount": 0, "results": [], "_stale": True}

    params = {
        "media": "software", "entity": "software", "country": country,
        "limit": str(FETCH_LIMIT), "term": term,
    }
    url = f"{ITUNES_ENDPOINT}?{urllib.parse.urlencode(params)}"
    for attempt in range(1, 5):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "aso-analyzer/1.0"})
            with urllib.request.urlopen(req, timeout=25) as r:
                data = json.loads(r.read().decode("utf-8"))
            cache.write_text(json.dumps(data))
            time.sleep(SLEEP_BETWEEN)
            return data
        except Exception as e:  # noqa: BLE001
            wait = 2 ** attempt
            print(f"  ! iTunes {country}/{term!r} attempt {attempt}: {e} -> retry {wait}s",
                  file=sys.stderr)
            time.sleep(wait)
    return {"resultCount": 0, "results": [], "_error": True}


def load_apple_popularity(db_path: Path) -> dict:
    """{(country, term_lower): (popularity, source)} from every free source
    RespectASO has already synced/computed locally.

    Priority when a term appears in several: apple official > RespectASO's
    own prior keyword run (apple field, then internal) > applesearchpopularity.
    """
    out: dict[tuple[str, str], tuple[int, str]] = {}
    if not db_path.exists():
        print(f"  (no RespectASO DB at {db_path} - all popularity estimated)", file=sys.stderr)
        return out

    def put(cc, term, pop, src, rank):
        if pop is None:
            return
        key = (cc, term.lower())
        cur = out.get(key)
        if cur is None or rank < cur[2]:
            out[key] = (int(pop), src, rank)

    con = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    try:
        for cc, term, pop in con.execute(
            """SELECT country, term, popularity FROM aso_appletopterm t
               WHERE week = (SELECT MAX(week) FROM aso_appletopterm t2
                             WHERE t2.country = t.country)"""
        ):
            put(cc, term, pop, "apple_official", 0)
        for cc, term, apop, ipop in con.execute(
            """SELECT sr.country, k.keyword, sr.apple_popularity_score, sr.popularity_score
               FROM aso_searchresult sr JOIN aso_keyword k ON k.id = sr.keyword_id"""
        ):
            put(cc, term, apop, "apple_official", 0)
            put(cc, term, ipop, "respectaso_estimate", 2)
        for cc, term, pop in con.execute(
            "SELECT country, term, popularity FROM aso_applesearchpopularity "
            "WHERE popularity IS NOT NULL"
        ):
            put(cc, term, pop, "apple_official", 1)
    finally:
        con.close()
    return {k: (v[0], v[1]) for k, v in out.items()}


def mine_candidates(db_path: Path, country: str, limit: int = 25) -> list[str]:
    """Card / table / messaging game terms from Apple's official top-terms list.

    Word-boundary allow-list plus a brand/genre block-list, so unrelated
    hits like 'cooking' (matches 'king') or 'car parking' don't leak in.
    """
    if not db_path.exists():
        return []
    con = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    try:
        rows = con.execute(
            """SELECT term, popularity FROM aso_appletopterm t
               WHERE country = ? AND genre = 'GAMES'
                 AND week = (SELECT MAX(week) FROM aso_appletopterm t2
                             WHERE t2.country = t.country AND t2.genre = 'GAMES')
               ORDER BY popularity DESC""",
            (country,),
        ).fetchall()
    finally:
        con.close()
    out = []
    for term, _ in rows:
        if (_MINE_ALLOW.search(term) and not _MINE_BLOCK.search(term)
                and not _OTHER_GAME.search(term)):
            out.append(term)
        if len(out) >= limit:
            break
    return out


# --------------------------------------------------------------------------
# scoring
# --------------------------------------------------------------------------

def _years_since(iso: str | None) -> float | None:
    if not iso:
        return None
    try:
        d = datetime.fromisoformat(iso.replace("Z", "+00:00"))
    except ValueError:
        return None
    return (datetime.now(timezone.utc) - d).days / 365.25


def _clamp(x: float, lo: float = 0.0, hi: float = 100.0) -> float:
    return max(lo, min(hi, x))


def difficulty(term: str, results: list[dict]) -> dict:
    """0-100 competition score from the iTunes result set (mirrors RespectASO)."""
    ranked = results[:TOP_N]
    n = len(ranked)
    if n == 0:
        return {"score": 0, "interpretation": "No data", "sample": 0}

    reviews = sorted((int(a.get("userRatingCount") or 0) for a in ranked), reverse=True)
    median_reviews = reviews[n // 2]
    avg_reviews = sum(reviews) / n
    top5_wall = reviews[min(4, n - 1)]  # reviews held by the #5 app = entry wall
    ratings = [float(a["averageUserRating"]) for a in ranked
               if a.get("averageUserRating")]
    avg_rating = sum(ratings) / len(ratings) if ratings else 0.0
    ages = [y for a in ranked if (y := _years_since(a.get("releaseDate"))) is not None]
    median_age = sorted(ages)[len(ages) // 2] if ages else 0.0
    sellers = [a.get("sellerName") or a.get("artistName") or "?" for a in ranked]
    uniq = len(set(sellers))

    tokens = [t for t in re.split(r"\s+", term.lower()) if t]
    title_hits = sum(
        1 for a in ranked
        if all(tok in (a.get("trackName") or "").lower() for tok in tokens)
    )

    def _log_scale(v, lo_exp, hi_exp):
        return _clamp(100 * (math.log10(v + 1) - lo_exp) / (hi_exp - lo_exp))

    # calibrated against RespectASO's published difficulty for 13 keywords x us
    rating_volume = _log_scale(median_reviews, 1.0, math.log10(400_000))
    entry_wall = _log_scale(top5_wall, 2.0, math.log10(500_000))
    big = sum(1 for r in reviews if r >= 1_000_000)
    huge = any(r >= 5_000_000 for r in reviews)
    dominant_players = _clamp(100 * big / n + (15 if huge else 0))
    rating_quality = _clamp((avg_rating - 3.0) / 1.8 * 100) if avg_rating else 45.0
    market_age = _clamp(median_age / 5.0 * 100)
    title_relevance = _clamp(100 * title_hits / n)

    score = round(_clamp(
        0.32 * rating_volume
        + 0.24 * entry_wall
        + 0.10 * dominant_players
        + 0.16 * title_relevance
        + 0.10 * rating_quality
        + 0.08 * market_age
    ))
    band = ("Extreme" if score >= 85 else "Very Hard" if score >= 70
            else "Hard" if score >= 52 else "Moderate" if score >= 37 else "Easy")
    return {
        "score": score, "interpretation": band, "sample": n,
        "median_reviews": median_reviews, "avg_reviews": round(avg_reviews),
        "top5_wall": top5_wall, "avg_rating": round(avg_rating, 2),
        "median_age_years": round(median_age, 1), "unique_publishers": uniq,
        "title_match": f"{title_hits}/{n}",
        "parts": {
            "rating_volume": round(rating_volume),
            "entry_wall": round(entry_wall),
            "dominant_players": round(dominant_players),
            "title_relevance": round(title_relevance),
            "rating_quality": round(rating_quality),
            "market_age": round(market_age),
        },
    }


def popularity(term: str, country: str, table: dict, itunes: dict) -> dict:
    key = (country, term.lower())
    if key in table:
        score, src = table[key]
        return {"score": int(score), "source": src,
                "estimated": src != "apple_official"}
    # No synced datapoint. Apple only reports terms above ~500 searches/wk
    # (its scale floors near 40), so an unlisted term is either genuinely
    # sub-threshold or just outside the 5 storefronts we have synced.
    # Approximate from how many apps compete for it.
    rc = int(itunes.get("resultCount") or 0)
    est = _clamp(14 + 28 * math.log10(rc + 1) / math.log10(200), 8, 42)
    return {"score": round(est), "source": "estimate", "estimated": True}


def classify(pop: int, diff: int) -> str:
    if pop < 18:
        return "Low Volume"
    if diff < 45 and pop >= 22:
        return "Sweet Spot"
    if diff < 58 and (pop - diff) > -14:
        return "Moderate"
    if diff >= 58 and pop >= 60:
        return "High Competition"
    if diff >= 58:
        return "Avoid"
    return "Moderate"


def relevance_ok(term: str) -> bool:
    """True when the keyword is about this app (its games or its format).

    A card game we do NOT have (solitaire, poker, spades...) is not relevant
    even though it contains 'card'-adjacent words - block those explicitly.
    """
    t = term.lower()
    if _OTHER_GAME.search(t):
        return False
    return bool(_RELEVANT.search(t))


_OTHER_GAME = re.compile(
    r"\b(solitaire|poker|spades|hearts|euchre|pinochle|canasta|cribbage|"
    r"whist|bridge|blackjack|uno|president|durak|skat|briscola|scopa|"
    r"mahjong|chess|checkers|dominoes|ludo)\b", re.I)


def our_rank(results: list[dict]) -> int | None:
    for i, a in enumerate(results, 1):
        if a.get("trackId") == OUR_TRACK_ID:
            return i
    return None


def recommend(row: dict) -> str:
    cls, pop, diff = row["classification"], row["popularity"], row["difficulty"]
    rank = row["rank"]
    if not row["relevant"]:
        if _OTHER_GAME.search(row["keyword"]):
            return "DROP (no matching game)"
        return "DROP (off-target)"
    if cls in ("Sweet Spot", "Moderate"):
        return "KEEP"
    if cls == "High Competition":
        return "KEEP" if (rank and rank <= 60) else "MAYBE (hard; not ranking)"
    if cls == "Low Volume":
        return "MAYBE (low volume)" if row["current"] else "SKIP (low volume)"
    return "DROP (avoid)"


# --------------------------------------------------------------------------
# orchestration
# --------------------------------------------------------------------------

_STOPWORDS = {"for", "and", "the", "a", "to", "of", "in", "with", "your", "my"}


def _stem(w: str) -> str:
    w = w.lower().strip(".,!'’")
    return w[:-1] if len(w) > 3 and w.endswith("s") else w


def field_tokens(*fields: str) -> set[str]:
    toks: set[str] = set()
    for f in fields:
        for part in re.split(r"[,\s]+", (f or "").lower()):
            if part:
                toks.add(_stem(part))
    return toks


def analyze_locale(meta: dict, locale: str, countries: list[str],
                   with_candidates: bool, offline: bool, pop_table: dict) -> dict:
    vloc = meta["version_localizations"]["keywords"]
    name = meta["app_info"]["name"].get(locale) or meta["app_info"]["name"]["en"]
    subtitle = meta["app_info"]["subtitle"].get(locale) or ""
    current_field = vloc.get(locale) or ""
    current_kws = [k.strip() for k in current_field.split(",") if k.strip()]

    kw_list = list(dict.fromkeys(current_kws))  # preserve order, dedupe
    if with_candidates:
        for c in BASE_CANDIDATES:
            kw_list.append(c)
        for cc in countries:
            for c in mine_candidates(RESPECTASO_DB, cc):
                kw_list.append(c)
    kw_list = list(dict.fromkeys(k.lower() for k in kw_list))

    covered = field_tokens(name, subtitle)
    rows: list[dict] = []
    for kw in kw_list:
        per_country = []
        for cc in countries:
            data = itunes_search(kw, cc, offline=offline)
            results = data.get("results", [])
            diff = difficulty(kw, results)
            pop = popularity(kw, cc, pop_table, data)
            rank = our_rank(results)
            per_country.append({
                "country": cc, "popularity": pop["score"],
                "popularity_estimated": pop["estimated"],
                "difficulty": diff["score"], "difficulty_band": diff["interpretation"],
                "classification": classify(pop["score"], diff["score"]),
                "rank": rank, "median_reviews": diff.get("median_reviews"),
                "title_match": diff.get("title_match"),
                "result_count": data.get("resultCount"),
            })
        primary = per_country[0]
        agg = {
            "keyword": kw,
            "current": kw in [k.lower() for k in current_kws],
            "relevant": relevance_ok(kw),
            "chars": len(kw),
            "popularity": primary["popularity"],
            "popularity_estimated": primary["popularity_estimated"],
            "difficulty": primary["difficulty"],
            "difficulty_band": primary["difficulty_band"],
            "classification": primary["classification"],
            "rank": primary["rank"],
            "median_reviews": primary["median_reviews"],
            "title_match": primary["title_match"],
            "by_country": per_country,
            "already_in_name_subtitle": all(
                _stem(tok) in covered
                for tok in re.split(r"\s+", kw) if tok and tok not in _STOPWORDS
            ),
        }
        agg["recommendation"] = recommend(agg)
        # opportunity: volume you could realistically capture
        agg["opportunity"] = round(
            agg["popularity"] * (1 - agg["difficulty"] / 100)
            * (0.4 if not agg["relevant"] else 1.0)
            * (0.5 if agg["already_in_name_subtitle"] else 1.0), 1)
        rows.append(agg)

    rows.sort(key=lambda r: r["opportunity"], reverse=True)
    proposed = assemble_field(rows, covered)
    return {
        "locale": locale, "countries": countries,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "name": name, "subtitle": subtitle,
        "current_field": current_field, "current_field_chars": len(current_field),
        "proposed_field": proposed, "proposed_field_chars": len(proposed),
        "keywords": rows,
    }


def assemble_field(rows: list[dict], covered: set[str], limit: int = 100) -> str:
    """Greedily fill a <=100-char field with the best usable keywords."""
    def usable(r: dict) -> bool:
        if r["already_in_name_subtitle"] or not r["relevant"]:
            return False
        if r["opportunity"] < 10:
            return False
        cls = r["classification"]
        if cls in ("Sweet Spot", "Moderate"):
            return True
        if cls == "High Competition" and r["rank"] and r["rank"] <= 80:
            return True
        return False  # Avoid / Low Volume / unranked High Competition

    picked: list[str] = []
    for r in sorted(rows, key=lambda r: r["opportunity"], reverse=True):
        if not usable(r):
            continue
        if len(",".join(picked + [r["keyword"]])) > limit:
            continue
        picked.append(r["keyword"])
    return ",".join(picked)


def write_outputs(res: dict) -> Path:
    loc_dir = OUT_ROOT / res["locale"]
    loc_dir.mkdir(parents=True, exist_ok=True)
    (loc_dir / "analysis.json").write_text(json.dumps(res, indent=2, ensure_ascii=False))

    with (loc_dir / "keywords.csv").open("w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["keyword", "current", "relevant", "chars", "popularity",
                    "pop_estimated", "difficulty", "band", "classification",
                    "rank", "median_reviews", "title_match", "opportunity",
                    "recommendation", "in_name_subtitle"])
        for r in res["keywords"]:
            w.writerow([r["keyword"], r["current"], r["relevant"], r["chars"],
                        r["popularity"], r["popularity_estimated"], r["difficulty"],
                        r["difficulty_band"], r["classification"], r["rank"],
                        r["median_reviews"], r["title_match"], r["opportunity"],
                        r["recommendation"], r["already_in_name_subtitle"]])

    (loc_dir / "report.md").write_text(render_md(res))
    return loc_dir


def render_md(res: dict) -> str:
    L = [
        f"# Keyword analysis - {res['locale']}  ({', '.join(res['countries'])})",
        f"_{res['generated_at']}_  ",
        f"Name: **{res['name']}**  |  Subtitle: **{res['subtitle'] or '-'}**",
        "",
        f"Current field ({res['current_field_chars']}/100): `{res['current_field']}`",
        "",
        f"**Proposed field ({res['proposed_field_chars']}/100):** `{res['proposed_field']}`",
        "",
        "| keyword | cur | pop | diff | band | class | rank | medRev | title | opp | recommendation |",
        "|---|:-:|--:|--:|---|---|:-:|--:|:-:|--:|---|",
    ]
    for r in res["keywords"]:
        pop = f"{r['popularity']}{'*' if r['popularity_estimated'] else ''}"
        L.append(
            f"| {r['keyword']} | {'Y' if r['current'] else ''} | {pop} | "
            f"{r['difficulty']} | {r['difficulty_band']} | {r['classification']} | "
            f"{r['rank'] or '-'} | {r['median_reviews'] if r['median_reviews'] is not None else '-'} | "
            f"{r['title_match'] or '-'} | {r['opportunity']} | {r['recommendation']} |"
        )
    L += ["", "`*` = popularity estimated (storefront not in Apple's synced data).",
          "`pop` 0-100 search demand, `diff` 0-100 competition, `opp` = realistic capturable volume.",
          "`rank` = current position of Card Games for iMessage in the iTunes result set (proxy)."]
    return "\n".join(L)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--locale", help="metadata.json locale key, e.g. en, en-GB, de")
    ap.add_argument("--all", action="store_true", help="every locale in metadata.json")
    ap.add_argument("--countries", help="override storefronts, comma-separated (e.g. gb,au,ca)")
    ap.add_argument("--candidates", action="store_true",
                    help="also score BASE_CANDIDATES + mined Apple top-terms")
    ap.add_argument("--offline", action="store_true", help="only use cached iTunes data")
    ap.add_argument("--report", choices=["md", "none"], default="md",
                    help="echo the markdown report to stdout (default md)")
    args = ap.parse_args()

    meta = json.loads(METADATA_PATH.read_text())
    locales = (list(LOCALE_COUNTRY) if args.all
               else [args.locale] if args.locale else None)
    if not locales:
        ap.error("pass --locale <key> or --all")

    pop_table = load_apple_popularity(RESPECTASO_DB)

    for locale in locales:
        if locale not in LOCALE_COUNTRY:
            print(f"skip unknown locale {locale!r}", file=sys.stderr)
            continue
        countries = (args.countries.split(",") if args.countries
                     else [LOCALE_COUNTRY[locale]])
        print(f"\n=== {locale}  ({', '.join(countries)}) ===", file=sys.stderr)
        res = analyze_locale(meta, locale, countries, args.candidates,
                             args.offline, pop_table)
        out_dir = write_outputs(res)
        print(f"  wrote {out_dir}", file=sys.stderr)
        if args.report == "md":
            print(render_md(res))


if __name__ == "__main__":
    main()
