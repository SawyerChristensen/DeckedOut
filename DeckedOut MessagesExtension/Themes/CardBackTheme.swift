//
//  CardBackTheme.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 5/18/26.
//

import Foundation

struct CardBackTheme: Identifiable {
    let id = UUID()
    var title: String
    var logoCard: String
    var price: String?
}
