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
    var fronts: String? = nil
    /// App Store Connect non-consumable IAP product ID. `nil` means this theme is free.
    var productID: String?
    /// Total wins (across all games) required to unlock this theme. `nil` means no win gate.
    var requiredWins: Int? = nil
    var primaryColor: Color //accent color used in Rules view
    var secondaryColor: Color = .white
}

extension DeckTheme {
    /// Master list of available themes. Anything that needs to know about all themes
    /// (the menu wheel, the selection's color lookup, etc.) reads from here.
    static let all: [DeckTheme] = [
        DeckTheme(title: "Classic Blue",
                  logoCard: "cardBackBlue",
                  productID: nil, //included
                  requiredWins: 2,
                  primaryColor: Color(red: 0, green: 84/255, blue: 166/255)),

        DeckTheme(title: "Classic Purple",
                  logoCard: "cardBackPurple",
                  productID: nil, //included
                  requiredWins: 1,
                  primaryColor: Color(red: 100/255, green: 0, blue: 200/255)),

        DeckTheme(title: "Classic Red",
                  logoCard: "cardBackRed",
                  productID: nil, //included
                  primaryColor: Palette.salmonRed),
        
        DeckTheme(title: "Sunset", /// $0.99  ->  $0.89
                  logoCard: "cardBackSunset",
                  productID: "Sawyer.DeckedOut.Theme.SunsetGradient",
                  primaryColor: Color(red: 255/255, green: 155/255, blue: 150/255)),
        
        DeckTheme(title: "Ocean", /// $0.99  ->  $0.89
                  logoCard: "cardBackOcean",
                  productID: "Sawyer.DeckedOut.Theme.OceanGradient",
                  primaryColor: Color(red: 35/255, green: 170/255, blue: 235/255)),
        
        DeckTheme(title: "Koi", /// $1.99   ->  $0.99
                  logoCard: "cardBackKoi",
                  productID: "Sawyer.DeckedOut.Theme.Koi",
                  primaryColor: Color(red: 100/255, green: 200/255, blue: 200/255), //blue
                  secondaryColor: Color(red: 251/255, green: 250/255, blue: 204/255)), //orangeish red
        
        DeckTheme(title: "Enchanted", /// $1.99
                  logoCard: "cardBackEnchanted",
                  fronts: "Enchanted",
                  productID: "Sawyer.DeckedOut.Theme.RedFoxEnchanted",
                  primaryColor: Color(red: 225/255, green: 30/255, blue: 40/255), //red
                  secondaryColor: Color(red: 121/255, green: 202/255, blue: 242/255)), //light blue
        
        DeckTheme(title: "Web", /// $1.99  ->  $0.99
                  logoCard: "cardBackWeb",
                  productID: "Sawyer.DeckedOut.Theme.Web",
                  primaryColor: Color(red: 0.10, green: 0.10, blue: 0.10)),
    ]

    /// Find a theme by its `logoCard` asset name. Returns nil if there is no match.
    static func theme(forLogoCard name: String) -> DeckTheme? {
        return all.first(where: { $0.logoCard == name })
    }
}

