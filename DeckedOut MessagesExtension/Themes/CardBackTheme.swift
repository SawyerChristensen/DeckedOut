//
//  CardBackTheme.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 5/18/26.
//

import SwiftUI

struct CardBackTheme: Identifiable {
    let id = UUID()
    var title: String
    var logoCard: String
    var price: String?
    var primaryColor: Color //accent color used in Rules view
    var secondaryColor: Color = .white
}

extension CardBackTheme {
    /// Master list of available themes. Anything that needs to know about all themes
    /// (the menu wheel, the selection's color lookup, etc.) reads from here.
    static let all: [CardBackTheme] = [
        CardBackTheme(title: "Classic Blue",
                      logoCard: "cardBackBlue",
                      price: nil,
                      primaryColor: Color(red: 0, green: 84/255, blue: 166/255)),
        
        CardBackTheme(title: "Classic Purple",
                      logoCard: "cardBackPurple",
                      price: nil,
                      primaryColor: Color(red: 100/255, green: 0, blue: 200/255)),
        
        CardBackTheme(title: "Classic Red",
                      logoCard: "cardBackRed",
                      price: nil,
                      primaryColor: Color("salmonRed")),
        
        CardBackTheme(title: "Sunset",
                      logoCard: "cardBackSunset",
                      price: "$0.99",
                      primaryColor: Color(red: 255/255, green: 155/255, blue: 150/255)),
        
        CardBackTheme(title: "Ocean",
                      logoCard: "cardBackOcean",
                      price: "$0.99",
                      primaryColor: Color(red: 35/255, green: 170/255, blue: 235/255)),
        
        CardBackTheme(title: "Koi",
                      logoCard: "cardBackKoi",
                      price: "$1.99",
                      primaryColor: Color(red: 100/1255, green: 200/255, blue: 200/255), //blue
                      secondaryColor: Color(red: 251/255, green: 250/255, blue: 204/255)), //orangeish red
        
        CardBackTheme(title: "Spider's Web",
                      logoCard: "cardBackWeb",
                      price: "$1.99",
                      primaryColor: Color(red: 0.10, green: 0.10, blue: 0.10)),
    ]

    /// Find a theme by its `logoCard` asset name. Returns nil if there is no match.
    static func theme(forLogoCard name: String) -> CardBackTheme? {
        return all.first(where: { $0.logoCard == name })
    }
}

