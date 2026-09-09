#!/usr/bin/env python3
"""Archive the current App Store keyword fields, then write the revised ones.

Step 1: snapshot metadata.json's current version_localizations.keywords into
        scripts/keyword_history.json (append a dated entry, never overwrite).
Step 2: replace each locale's keyword field with the revised NEW_KEYWORDS below.

Revision rules applied by hand when building NEW_KEYWORDS:
  - no spaces inside a term (Apple recombines individual words itself)
  - no word that already appears in that locale's app name or subtitle
  - no keywords for games this app does not contain (poker, solitaire,
    hearts, spades, bridge, canasta, scopa, sueca, mahjong, ...)
  - keep the local Crazy 8s / Gin Rummy variant only when the subtitle
    doesn't already carry it
  - backfill freed space with the couple / long-distance / turn-based /
    two-player / quick-play cluster in each language

Run:  python update_keywords.py --dry-run     # show the diff, write nothing
      python update_keywords.py                # archive + rewrite metadata.json
"""
from __future__ import annotations

import argparse
import json
import re
from datetime import date
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
METADATA_PATH = SCRIPT_DIR / "metadata.json"
HISTORY_PATH = SCRIPT_DIR / "keyword_history.json"

# Revised keyword fields. All <=100 chars, comma-separated, no internal spaces,
# no repeats of the locale's name/subtitle words.
NEW_KEYWORDS: dict[str, str] = {
    "en":
        "eights,pigeon,turn,based,1v1,two,player,couples,date,night,long,distance,family,friends",
    "en-GB":
        "eights,crazy,pigeon,turn,based,1v1,two,player,couples,date,night,long,distance,family",
    "da":
        "olsen,gin,rummy,golf,par,kærester,afstand,turbaseret,to,spillere,multiplayer,online,gratis",
    "de":
        "MauMau,Gin,Rummy,Mehrspieler,zu,zweit,Paare,Fernbeziehung,rundenbasiert,Freunde,online,gratis,1v1",
    "es":
        "parejas,novios,distancia,por,turnos,dos,jugadores,sin,conexion,duelo,multijugador,online,1v1,solo",
    "fi":
        "kasi,kahdeksikko,gin,rommi,golf,pari,etäsuhde,vuoropohjainen,kaksin,ilmainen,moninpeli,online,1v1",
    "fr":
        "rami,gin,8,americain,couple,distance,tour,par,deux,joueurs,partie,rapide,duel,1v1,gratuit",
    "hi":
        "रम्मी,जिन,क्रेजी,8,ताश,मल्टीप्लेयर,1v1,दूरी,कपल,बारी,दो,खिलाड़ी,मुकाबला,मज़ा,फ्री",
    "it":
        "gin,rummy,ramino,otto,americano,golf,coppie,distanza,turni,due,giocatori,veloce,1v1,gratis",
    "ja":
        "ジンラミー,ラミー,クレイジーエイト,ゴルフ,二人,カップル,遠距離,ターン制,対人,暇つぶし,脳トレ,オンライン",
    "ko":
        "라미,크레이지에잇,보드게임,커플,원거리,턴제,2인용,친구,대전,전략,심심풀이,무료,내기,실시간",
    "nb":
        "vriåtter,olsen,gin,rummy,golf,par,avstand,turbasert,to,spillere,flerspiller,gratis,klassisk",
    "nl":
        "rummy,kaarten,koppels,afstand,beurten,twee,spelers,vrienden,multiplayer,gratis,1v1,solo",
    "pl":
        "makao,remik,karty,pary,odleglosc,turowa,dwoch,graczy,szybka,online,darmowe,znajomi,1v1,dwoje",
    "pt-BR":
        "rami,oito,maluco,baralho,casais,distancia,turnos,dois,jogadores,dupla,multiplayer,amigos",
    "pt-PT":
        "rami,casais,distancia,turnos,dois,jogadores,dupla,online,duelo,amigos,1v1,gratis,solo,longa",
    "ru":
        "Джин,Карты,пары,расстояние,ходы,вдвоём,быстрая,Онлайн,Друзья,1на1,Классика,стратегия,колода",
    "sv":
        "gin,par,distans,turordning,två,spelare,snabbt,multiplayer,vänner,gratis,1v1,solo,kortlek",
    "tr":
        "remi,gin,rummy,çılgın,sekizli,golf,çift,mesafe,sıra,iki,kişilik,hızlı,arkadaş,1v1,düello",
    "vi":
        "phỏm,cặp,đôi,từ,xa,lượt,hai,người,bạn,bè,cổ,điển,miễn,phí,nhiều,chơi",
    "zh-Hans":
        "拉米,疯狂八,棋牌,卡牌,经典,多人,联网,对战,好友,策略,情侣,异地,异地恋,回合制,轮流,双人,两人,快速,单挑,免费,休闲,益智,约会,桌游",
    "zh-Hant":
        "拉米,瘋狂八,棋牌,卡牌,經典,多人,連網,對戰,好友,策略,情侶,遠距離,遠距離戀愛,輪流,回合制,雙人,兩人,快速,單挑,免費,休閒,益智,約會,桌遊",
}


def validate(field: str, name: str, subtitle: str, locale: str) -> list[str]:
    problems = []
    if len(field) > 100:
        problems.append(f"{locale}: {len(field)} chars (>100)")
    for term in field.split(","):
        if " " in term:
            problems.append(f"{locale}: term with space -> {term!r}")
        if not term:
            problems.append(f"{locale}: empty term")
    ns_words = {w.lower().strip(".,!?:;&") for w in re.split(r"[\s,]+", f"{name} {subtitle}") if w}
    dupes = [t for t in field.split(",") if t.lower() in ns_words]
    if dupes:
        problems.append(f"{locale}: repeats name/subtitle word(s): {dupes}")
    seen, rep = set(), []
    for t in field.split(","):
        if t.lower() in seen:
            rep.append(t)
        seen.add(t.lower())
    if rep:
        problems.append(f"{locale}: duplicate term(s): {rep}")
    return problems


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dry-run", action="store_true", help="show diff, write nothing")
    args = ap.parse_args()

    meta = json.loads(METADATA_PATH.read_text())
    kw = meta["version_localizations"]["keywords"]
    names = meta["app_info"]["name"]
    subs = meta["app_info"]["subtitle"]
    locales = [l for l in meta["_meta"]["locales"]]

    missing = [l for l in locales if l not in NEW_KEYWORDS]
    if missing:
        raise SystemExit(f"NEW_KEYWORDS missing locales: {missing}")

    all_problems = []
    print(f"{'locale':7} {'old':>4} {'new':>4}  change")
    print("-" * 100)
    for loc in locales:
        old = kw.get(loc) or ""
        new = NEW_KEYWORDS[loc]
        all_problems += validate(new, names.get(loc, names["en"]), subs.get(loc, ""), loc)
        print(f"{loc:7} {len(old):>4} {len(new):>4}")
        print(f"        - {old}")
        print(f"        + {new}")

    if all_problems:
        print("\nVALIDATION PROBLEMS:")
        for p in all_problems:
            print(f"  ! {p}")
        raise SystemExit("fix NEW_KEYWORDS before writing")
    print("\nvalidation: OK (all <=100, no spaces, no name/subtitle repeats, no dup terms)")

    if args.dry_run:
        print("\n--dry-run: nothing written")
        return

    # ---- archive current, then rewrite ----
    history = json.loads(HISTORY_PATH.read_text()) if HISTORY_PATH.exists() else []
    history.append({
        "archived_on": date.today().isoformat(),
        "note": "pre-revision snapshot (before despace + subtitle-dedupe + drop non-owned games)",
        "keywords": {loc: (kw.get(loc) or "") for loc in locales},
    })
    HISTORY_PATH.write_text(json.dumps(history, indent=2, ensure_ascii=False) + "\n")
    print(f"\narchived current keywords -> {HISTORY_PATH.name} "
          f"({len(history)} snapshot(s) total)")

    for loc in locales:
        kw[loc] = NEW_KEYWORDS[loc]
    METADATA_PATH.write_text(json.dumps(meta, indent=2, ensure_ascii=False) + "\n")
    print(f"updated {len(locales)} keyword fields in {METADATA_PATH.name}")


if __name__ == "__main__":
    main()
