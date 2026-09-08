//
//  DeckInviteChant.swift
//  DeckedOut
//
//  The word "pages" the invite transcript hand flips between, one glyph per card
//  (see `GolfTranscriptInviteHand`, `GinTranscriptInviteHand`, and the `.crazy8s`
//  case of `Crazy8sVariant.titleWords`). Shared by every game's invite hand so the
//  "let's play …" chant is localized in one place.
//
//  Two hard constraints shape every entry below.
//
//  1. ONE GLYPH PER CARD, AND THE FAN IS AS WIDE AS THE LONGEST PAGE.
//     `getChar` pads a short page's tail with spaces and `LetterCardImage` draws a
//     space as a blank card face, so a three-character page next to a six-character
//     one reads as a mostly-empty hand that never fills in. Every page of a given
//     game's chant is therefore kept within one character of every other page.
//     `lead` is two pages of "let's play"; the game name that follows is picked to
//     land within one of the lead. Most leads are 5 glyphs (see constraint 2 for
//     why), so the 4-letter names GOLF / GIN! are written " GOLF" / " GIN!" — the
//     leading space centres the word in the 5-wide fan ([_][G][O][L][F]) instead of
//     letting it sit left-aligned with the blank trailing ([G][O][L][F][_]).
//     The three 4,4 leads (en, da, tr) take the bare "GOLF" / "GIN!" for a flush
//     4-card fan.
//
//  2. THE DECK FONTS ARE ASCII-ONLY.
//     Letter cards render in the active card back's display font, and the default
//     back (`cardBackRed`) uses Holtzschue, whose cmap is A–Z / a–z / 0–9 only — no
//     accents, and no punctuation beyond the pre-rendered "!" that `LetterCardImage`
//     special-cases. Kingthings Widow (Web) is likewise unaccented ASCII. So the
//     Latin-script chants are written WITHOUT diacritics: "SPIEL MIT" not "SPIEL"
//     with an umlaut, "TOCA JUGAR" not "¡A JUGAR!". A page that needs a diacritic
//     silently falls back to the system serif on those decks and breaks the
//     typeface mid-word. "!" is safe on every deck; "?" and "'" are not.
//
//  Each card renders a single `Character` from `Array(word)`, so a page also has to
//  be a script with no separate combining marks. Devanagari (hi) and Vietnamese
//  (vi) both need marks that constraint 2 rules out, so those two locales are left
//  out of `forms` and fall back to the English chant.
//

import Foundation

enum DeckInviteChantGame {
    case golf, gin, crazy8s
}

enum DeckInviteChant {

    /// One glyph per card; the fan is as wide as the longest page and shorter pages
    /// trail off into blank cards (`GolfTranscriptInviteHand.charCount`).
    static func words(for game: DeckInviteChantGame) -> [String] {
        let form = forms[localeKey] ?? english

        switch game {
        case .golf:    return form.lead + form.golf
        case .gin:     return form.lead + form.gin
        case .crazy8s: return form.lead + form.crazy8s
        }
    }

    /// The key into `forms`: the bare language subtag, except for Chinese, which is
    /// keyed by script because the two write the chant differently.
    ///
    /// Resolved through `Locale.Language` rather than `hasPrefix` on the raw tag —
    /// prefix matching quietly mis-keys neighbouring codes (a `fil-PH` device has a
    /// tag starting "fi", and would otherwise have been served the Finnish chant).
    private static var localeKey: String {
        let preferred = Locale.preferredLanguages.first ?? "en"
        let language = Locale.Language(identifier: preferred)
        guard let code = language.languageCode?.identifier else { return "en" }
        guard code == "zh" else { return code }

        // "zh-TW" and a bare "zh" carry no script subtag; maximalIdentifier fills in
        // the one CLDR infers for the region ("zh-TW" → "zh-Hant-TW").
        let script = Locale.Language(identifier: language.maximalIdentifier).script?.identifier
        return "zh-\(script ?? "Hans")"
    }

    private struct ChantForm {
        let lead: [String]              // the "let's play" pages, ahead of the game name
        var golf    = [" GOLF"]         // 5-wide leads centre the 4-letter name; 4,4 leads override with ["GOLF"]
        var gin     = [" GIN!"]
        var crazy8s = ["CRAZY", "EIGHT"] // two equal spellings of "Crazy 8s"; localized names override
    }

    private static let english = ChantForm(lead: ["LETS", "PLAY"], golf: ["GOLF"], gin: ["GIN!"])

    // Latin-script leads are two pages of 4–5 unaccented characters. Several read as
    // the local idiom for "join in / play along" rather than a literal "let's play",
    // since those are the phrasings that land in that window without a diacritic —
    // and they carry no "!", which would be punctuation mid-phrase.
    //
    // A lead word shorter than the fan is padded with spaces on BOTH sides so it sits
    // centred rather than left-aligned — `getChar` only ever pads the tail, so " MED "
    // is the difference between [_][M][E][D][_] and [M][E][D][_][_]. Danish is the one
    // 4-wide lead here, hence " MED" (one side only) — it centres in Danish's own fans.
    private static let forms: [String: ChantForm] = [
        "en": english,
        "de": ChantForm(lead: ["SPIEL", " MIT "]),                         // "Spiel mit" — join in (avoids FÜRS)
        "nl": ChantForm(lead: ["SPEEL", " MEE "]),                         // "Speel mee" — join in
        "da": ChantForm(lead: ["SPIL",  " MED"], golf: ["GOLF"], gin: ["GIN!"],
                        crazy8s: ["OLSEN"]),                               // Danish plays Crazy 8s as "Olsen"; 4,4 lead
        "nb": ChantForm(lead: ["SPILL", " MED "]),                         // "Spill med" — join in
        "sv": ChantForm(lead: ["SPELA", " MED "], crazy8s: ["VAND", "ATTA"]), // "Vändåtta" ("vänd" + "åtta"), unaccented, split 4,4
        "fi": ChantForm(lead: ["PELAA", " NYT "]),                         // "Pelaa nyt" — play now
        "es": ChantForm(lead: ["TOCA",  "JUGAR"], crazy8s: ["OCHOS", "LOCOS"]), // "Ochos Locos"
        "pt": ChantForm(lead: ["VAMOS", "JOGAR"]),                         // "Vamos jogar"; "Oito Maluco" (4,6) won't split even, keep CRAZY/EIGHT
        "fr": ChantForm(lead: ["ALLEZ", "JOUEZ"]),                         // "Allez, jouez"; "8 américain" needs an accent, keep CRAZY/EIGHT
        "it": ChantForm(lead: ["FORZA", "GIOCA"], crazy8s: ["OTTO"]),      // "Otto Americano" → "OTTO" (4)
        "pl": ChantForm(lead: ["GRAMY", "RAZEM"]),                         // "Gramy razem" — we play together
        "tr": ChantForm(lead: ["HADI",  "OYNA"], golf: ["GOLF"], gin: ["GIN!"]), // "Hadi oyna"; "Çılgın 8'li" won't split, keep CRAZY/EIGHT; 4,4 lead

        // Non-Latin scripts. No unaccented-ASCII constraint to satisfy, but they do
        // fall back to the system serif on the decks whose display font is Latin-only
        // — the same tradeoff these locales already shipped with.
        "ru": ChantForm(lead: ["ДАВАЙ", "ИГРАЙ"],
                        golf: ["ГОЛЬФ"], gin: ["ДЖИН"], crazy8s: ["ВОСЬ", "МЁРКИ"]), // "Восьмёрки" split 4,5
        "ja": ChantForm(lead: ["みんなで", "あそぼう"],
                        golf: ["ゴルフ"], gin: ["ジンラミー"], crazy8s: ["クレイジー", " エイト"]), // " エイト" centres in the 5-wide fan
        "ko": ChantForm(lead: ["같이", "즐겨요"],
                        golf: ["골프"], gin: ["진러미"], crazy8s: ["크레", "이지8"]),  // "크레이지 8" split to hold the fan at 3
        "zh-Hant": ChantForm(lead: ["讓我們", "一起玩"],
                             golf: ["高爾夫"], gin: ["金拉米"], crazy8s: ["瘋狂8"]),
        "zh-Hans": ChantForm(lead: ["让我们", "一起玩"],
                             golf: ["高尔夫"], gin: ["金拉米"], crazy8s: ["疯狂8"]),
    ]
}
