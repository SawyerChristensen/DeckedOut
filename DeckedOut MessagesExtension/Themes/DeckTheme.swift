//
//  DeckTheme.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 5/18/26.
//

import SwiftUI

struct DeckTheme: Identifiable {
    let id = UUID()
    var title: String
    var logoCard: String
    /// Suffix appended to default card-front asset names to look up this theme's custom fronts
    /// (e.g. `"Enchanted"` turns `aceClubs` into `aceClubsEnchanted`). `nil` uses the default fronts.
    /// Note: a theme can set this to swap in only *some* custom fronts (e.g. American Flag themes just
    /// the jokers) — so this is NOT a reliable signal for whether the whole deck is themed. Use
    /// `isFullDeck` for that.
    var fronts: String? = nil
    /// Whether this theme provides custom artwork for *every* card front (a "Full Deck"), as opposed to
    /// just a themed card back (and possibly a few themed fronts like the jokers). Drives the store's
    /// "Card Back" vs "Full Deck" label.
    var isFullDeck: Bool = false
    /// App Store Connect non-consumable IAP product ID. `nil` means this theme is free.
    var productID: String?
    /// Total wins (across all games) required to unlock this theme. `nil` means no win gate.
    var requiredWins: Int? = nil
    /// ISO 3166-1 alpha-2 country code this theme is region-gated to (e.g. `"US"`). `nil` means the
    /// theme is shown everywhere. Flag themes are only visible when the device region OR the App Store
    /// storefront matches, so players generally only see the flag of the country they're tied to.
    var regionCode: String? = nil
    var rulesColor: Color //accent color used in Rules view
    var textColor: Color = .white //color used for text in
    /// Color of the subtle glow behind the card letters, used to help them stand out from the card
    /// back. `nil` falls back to `textColor` so the glow matches the letters by default.
    var outlineColor: Color? = nil
}

extension DeckTheme {
    /// Master list of available themes. Anything that needs to know about all themes
    /// (the menu wheel, the selection's color lookup, etc.) reads from here.
    static let all: [DeckTheme] = [
        DeckTheme(title: "Classic Blue",
                  logoCard: "cardBackBlue",
                  productID: nil, //included
                  //requiredWins: 2,
                  rulesColor: Color(red: 0, green: 84/255, blue: 166/255)),

        DeckTheme(title: "Classic Purple",
                  logoCard: "cardBackPurple",
                  productID: nil, //included
                  //requiredWins: 1,
                  rulesColor: Color(red: 100/255, green: 0, blue: 200/255)),

        DeckTheme(title: "Classic Red",
                  logoCard: "cardBackRed",
                  productID: nil, //included
                  rulesColor: Color.salmonRed),
        
        // MARK: Gradient Series
        DeckTheme(title: "Sunset",
                  logoCard: "cardBackSunset",
                  //productID: "Sawyer.DeckedOut.Theme.SunsetGradient",
                  requiredWins: 1,
                  rulesColor: Color(red: 255/255, green: 155/255, blue: 150/255)),
        
        DeckTheme(title: "Ocean",
                  logoCard: "cardBackOcean",
                  //productID: "Sawyer.DeckedOut.Theme.OceanGradient",
                  requiredWins: 2,
                  rulesColor: Color(red: 35/255, green: 170/255, blue: 235/255)),
        
        // MARK: Custom Series
        DeckTheme(title: "Koi", /// $1
                  logoCard: "cardBackKoi",
                  productID: "Sawyer.DeckedOut.Theme.Koi",
                  rulesColor: Color(red: 100/255, green: 200/255, blue: 200/255), //blue
                  textColor: Color(red: 251/255, green: 250/255, blue: 204/255)), //orangeish red
        
        DeckTheme(title: "Spider's Web", /// $1
                  logoCard: "cardBackWeb",
                  fronts: "Web", // only the ace of spades is themed; every other front falls back to default
                  productID: "Sawyer.DeckedOut.Theme.Web",
                  rulesColor: Color(red: 0.10, green: 0.10, blue: 0.10)),
        
        // MARK: Country Series
        DeckTheme(title: "American Flag", /// $1
                  logoCard: "cardBackAmerica",
                  fronts: "America", // only the jokers & ace of spades is themed; every other front falls back to default
                  productID: "Sawyer.DeckedOut.Theme.AmericanFlag",
                  regionCode: "US",
                  rulesColor: Color(red: 179/255, green: 25/255, blue: 66/255), //red
                  outlineColor: Color(red: 179/255, green: 25/255, blue: 66/255)), //red
        
        DeckTheme(title: "Australian Flag", /// $1
                  logoCard: "cardBackAustralia",
                  productID: "Sawyer.DeckedOut.Theme.AustralianFlag",
                  regionCode: "AU",
                  rulesColor: Color(red: 1/255, green: 33/255, blue: 105/255), //union jack blue
                  textColor: Color(red: 1/255, green: 33/255, blue: 105/255), //union jack blue
                  outlineColor: Color(red: 255/255, green: 255/255, blue: 255/255)), //white

        DeckTheme(title: "Austrian Flag", /// $1
                  logoCard: "cardBackAustria",
                  productID: "Sawyer.DeckedOut.Theme.AustrianFlag",
                  regionCode: "AT",
                  rulesColor: Color(red: 200/255, green: 16/255, blue: 46/255), //red
                  textColor: Color(red: 255/255, green: 255/255, blue: 255/255), //white
                  outlineColor: Color(red: 200/255, green: 16/255, blue: 46/255)), //red

        DeckTheme(title: "Brazilian Flag", /// $1
                  logoCard: "cardBackBrazil",
                  productID: "Sawyer.DeckedOut.Theme.BrazilianFlag",
                  regionCode: "BR",
                  rulesColor: Color(red: 0, green: 148/255, blue: 64/255), //green
                  textColor: Color(red: 1, green: 1, blue: 1)),
        
        DeckTheme(title: "British Flag", /// $1
                  logoCard: "cardBackUK",
                  productID: "Sawyer.DeckedOut.Theme.BritishFlag",
                  regionCode: "GB",
                  rulesColor: Color(red: 1/255, green: 33/255, blue: 105/255), //blue
                  textColor: Color(red: 200/255, green: 16/255, blue: 46/255), //red
                  outlineColor: Color(red: 255/255, green: 255/255, blue: 255/255)), //white
        
        DeckTheme(title: "Canadian Flag", /// $1
                  logoCard: "cardBackCanada",
                  productID: "Sawyer.DeckedOut.Theme.CanadianFlag",
                  regionCode: "CA",
                  rulesColor: Color(red: 235/255, green: 45/255, blue: 55/255)),

        DeckTheme(title: "Danish Flag", /// $1
                  logoCard: "cardBackDenmark",
                  productID: "Sawyer.DeckedOut.Theme.DanishFlag",
                  regionCode: "DK",
                  rulesColor: Color(red: 200/255, green: 16/255, blue: 46/255), //red
                  textColor: Color(red: 255/255, green: 255/255, blue: 255/255), //white
                  outlineColor: Color(red: 200/255, green: 16/255, blue: 46/255)), //red

        DeckTheme(title: "Dutch Flag", /// $1
                  logoCard: "cardBackNetherlands",
                  productID: "Sawyer.DeckedOut.Theme.DutchFlag",
                  regionCode: "NL",
                  rulesColor: Color(red: 173/255, green: 29/255, blue: 37/255), //Dutch red
                  textColor: Color(red: 0/255, green: 0/255, blue: 0/255)), //black
                  //glowColor: Color(red: 174/255, green: 28/255, blue: 40/255)), //Color(red: 33/255, green: 70/255, blue: 139/255)), //blue

        DeckTheme(title: "Finnish Flag", /// $1
                  logoCard: "cardBackFinland",
                  productID: "Sawyer.DeckedOut.Theme.FinnishFlag",
                  regionCode: "FI",
                  rulesColor: Color(red: 0/255, green: 47/255, blue: 108/255), //blue
                  textColor: Color(red: 0/255, green: 47/255, blue: 108/255), //blue
                  outlineColor: Color(red: 255/255, green: 255/255, blue: 255/255)), //white

        DeckTheme(title: "French Flag", /// $1
                  logoCard: "cardBackFrance",
                  productID: "Sawyer.DeckedOut.Theme.FrenchFlag",
                  regionCode: "FR",
                  rulesColor: Color(red: 0/255, green: 38/255, blue: 84/255),
                  textColor: Color(red: 0/255, green: 0/255, blue: 0/255)),
        
        DeckTheme(title: "German Flag", /// $1
                  logoCard: "cardBackGermany",
                  productID: "Sawyer.DeckedOut.Theme.GermanFlag",
                  regionCode: "DE",
                  rulesColor: Color(red: 0, green: 0, blue: 0),
                  textColor: Color(red: 255/255, green: 206/255, blue: 13/255)), //yellow
        
        DeckTheme(title: "Indian Flag", /// $1
                  logoCard: "cardBackIndia",
                  productID: "Sawyer.DeckedOut.Theme.IndianFlag",
                  regionCode: "IN",
                  rulesColor: Color(red: 255/255, green: 103/255, blue: 31/255), //orange
                  textColor: Color(red: 255/255, green: 255/255, blue: 255/255), //white
                  outlineColor: Color(red: 6/255, green: 3/255, blue: 141/255)), //navy

        DeckTheme(title: "Irish Flag", /// $1
                  logoCard: "cardBackIreland",
                  productID: "Sawyer.DeckedOut.Theme.IrishFlag",
                  regionCode: "IE",
                  rulesColor: Color(red: 22/255, green: 155/255, blue: 98/255), //green
                  textColor: Color(red: 0, green: 0, blue: 0)), //black

        DeckTheme(title: "Italian Flag", /// $1
                  logoCard: "cardBackItaly",
                  productID: "Sawyer.DeckedOut.Theme.ItalianFlag",
                  regionCode: "IT",
                  rulesColor: Color(red: 0/255, green: 146/255, blue: 70/255),
                  textColor: Color(red: 0, green: 0, blue: 0)),
        
        DeckTheme(title: "Japanese Flag", /// $1
                  logoCard: "cardBackJapan",
                  productID: "Sawyer.DeckedOut.Theme.JapaneseFlag",
                  regionCode: "JP",
                  rulesColor: Color(red: 188/255, green: 0/255, blue: 45/255), //red
                  textColor: Color(red: 255/255, green: 255/255, blue: 255/255)),
                  //glowColor: Color(red: 255/255, green: 255/255, blue: 255/255)), //red
        
        DeckTheme(title: "Korean Flag", /// $1
                  logoCard: "cardBackKorea",
                  productID: "Sawyer.DeckedOut.Theme.KoreanFlag",
                  regionCode: "KR",
                  rulesColor: Color(red: 1, green: 1, blue: 1)),
        
        DeckTheme(title: "Mexican Flag", /// $1
                  logoCard: "cardBackMexico",
                  productID: "Sawyer.DeckedOut.Theme.MexicanFlag",
                  regionCode: "MX",
                  rulesColor: Color(red: 4/255, green: 105/255, blue: 72/255), //green
                  textColor: Color(red: 144/255, green: 71/255, blue: 32/255)), //white
                  //glowColor: Color(red: 213/255, green: 168/255, blue: 105/255)), //brown

        DeckTheme(title: "Norwegian Flag", /// $1
                  logoCard: "cardBackNorway",
                  productID: "Sawyer.DeckedOut.Theme.NorwegianFlag",
                  regionCode: "NO",
                  rulesColor: Color(red: 186/255, green: 12/255, blue: 47/255), //red
                  textColor: Color(red: 0/255, green: 32/255, blue: 91/255), //blue
                  outlineColor: Color(red: 255/255, green: 255/255, blue: 255/255)), //white
        
        DeckTheme(title: "Polish Flag", /// $1
                  logoCard: "cardBackPoland",
                  productID: "Sawyer.DeckedOut.Theme.PolishFlag",
                  regionCode: "PL",
                  rulesColor: Color(red: 220/255, green: 20/255, blue: 60/255), //red
                  textColor: Color(red: 255/255, green: 255/255, blue: 255/255), //black
                  outlineColor: Color(red: 220/255, green: 20/255, blue: 60/255)), //red
        
        DeckTheme(title: "Portuguese Flag", /// $1
                  logoCard: "cardBackPortugal",
                  productID: "Sawyer.DeckedOut.Theme.PortugueseFlag",
                  regionCode: "PT",
                  rulesColor: Color(red: 0/255, green: 0/255, blue: 255/255), //red
                  textColor: Color(red: 255/255, green: 255/255, blue: 0/255)), //yellow
                  //outlineColor: Color(red: 218/255, green: 41/255, blue: 28/255)), //red

        DeckTheme(title: "Russian Flag", /// $1
                  logoCard: "cardBackRussia",
                  productID: "Sawyer.DeckedOut.Theme.RussianFlag",
                  regionCode: "RU",
                  rulesColor: Color(red: 0/255, green: 56/255, blue: 164/255)),
        
        DeckTheme(title: "Spanish Flag", /// $1
                  logoCard: "cardBackSpain",
                  productID: "Sawyer.DeckedOut.Theme.SpanishFlag",
                  regionCode: "ES",
                  rulesColor: Color(red: 173/255, green: 21/255, blue: 25/255), //red
                  textColor: Color(red: 255/255, green: 196/255, blue: 0/255), //white
                  outlineColor: Color(red: 173/255, green: 21/255, blue: 25/255)), //red

        DeckTheme(title: "Swedish Flag", /// $1
                  logoCard: "cardBackSweden",
                  productID: "Sawyer.DeckedOut.Theme.SwedishFlag",
                  regionCode: "SE",
                  rulesColor: Color(red: 0/255, green: 82/255, blue: 147/255), //blue
                  textColor: Color(red: 254/255, green: 203/255, blue: 0/255), //yellow
                  outlineColor: Color(red: 0/255, green: 82/255, blue: 147/255)), //blue
        
        DeckTheme(title: "Swiss Flag", /// $1
                  logoCard: "cardBackSwitzerland",
                  productID: "Sawyer.DeckedOut.Theme.SwissFlag",
                  regionCode: "CH",
                  rulesColor: Color(red: 255/255, green: 0/255, blue: 0/255), //red
                  textColor: Color(red: 255/255, green: 255/255, blue: 255/255), //white
                  outlineColor: Color(red: 255/255, green: 0/255, blue: 0/255)), //red
        
        DeckTheme(title: "Turkish Flag", /// $1
                  logoCard: "cardBackTurkey",
                  productID: "Sawyer.DeckedOut.Theme.TurkishFlag",
                  regionCode: "TR",
                  rulesColor: Color(red: 227/255, green: 10/255, blue: 23/255), //red
                  textColor: Color(red: 255/255, green: 255/255, blue: 255/255), //white
                  outlineColor: Color(red: 227/255, green: 10/255, blue: 23/255)), //red

        DeckTheme(title: "Vietnamese Flag", /// $1
                  logoCard: "cardBackVietnam",
                  productID: "Sawyer.DeckedOut.Theme.VietnameseFlag",
                  regionCode: "VN",
                  rulesColor: Color(red: 218/255, green: 37/255, blue: 29/255), //red
                  textColor: Color(red: 255/255, green: 255/255, blue: 0/255), //yellow
                  outlineColor: Color(red: 218/255, green: 37/255, blue: 29/255)), //red

        // MARK: Full Deck Series
        DeckTheme(title: "Enchanted", /// $2
                  logoCard: "cardBackEnchanted",
                  fronts: "Enchanted",
                  isFullDeck: true,
                  productID: "Sawyer.DeckedOut.Theme.RedFoxEnchanted",
                  rulesColor: Color(red: 121/255, green: 202/255, blue: 242/255), //light blue
                  textColor: Color(red: 255/255, green: 255/255, blue: 255/255)), //white
    ]

    
    // MARK: - Region Availability Check
    
    /// Maps the ISO 3166-1 *alpha-3* codes reported by the App Store storefront to the *alpha-2* codes
    /// used by `regionCode` (and by `Locale.region`). Only needs to cover the countries that have flag
    /// themes — when adding a new flag theme, add its alpha-3 → alpha-2 entry here too.
    private static let storefrontAlpha3ToAlpha2: [String: String] = [
        "USA": "US", "AUS": "AU", "AUT": "AT", "BRA": "BR", "GBR": "GB", "CAN": "CA",
        "DNK": "DK", "NLD": "NL", "FIN": "FI", "FRA": "FR", "DEU": "DE", "IND": "IN",
        "IRL": "IE", "ITA": "IT", "JPN": "JP", "KOR": "KR", "MEX": "MX", "NOR": "NO",
        "POL": "PL", "PRT": "PT", "RUS": "RU", "ESP": "ES", "SWE": "SE", "CHE": "CH",
        "TUR": "TR", "VNM": "VN",
    ]

    /// Themes available to show in the menu. Region-gated themes (the country flags) are included when
    /// their `regionCode` matches EITHER the device's current region OR the App Store storefront's
    /// country — so players see the flag of the country they're tied to — OR when the player already
    /// owns that flag, so a flag purchased abroad never disappears when they travel out of that region.
    /// Non-gated themes are always included.
    ///
    /// Main-actor isolated because it reads `StoreManager` state; it's only ever read from the menu UI,
    /// which already runs on the main actor.
    @MainActor
    static var available: [DeckTheme] {
        let deviceRegion = Locale.current.region?.identifier
        let store = StoreManager.shared
        let storeRegion = store.storefrontCountryCode.flatMap { storefrontAlpha3ToAlpha2[$0] }
        return all.filter { theme in
            guard let region = theme.regionCode else { return true }
            if region == deviceRegion || region == storeRegion { return true }
            // Only a flag purchased directly follows the player out of its region. Master unlock
            // does NOT reveal out-of-region flags — those reappear when the player's region matches.
            return store.directlyOwns(theme.productID)
        }
    }

    /// Find a theme by its `logoCard` asset name. Returns nil if there is no match.
    static func theme(forLogoCard name: String) -> DeckTheme? {
        return all.first(where: { $0.logoCard == name })
    }
}
