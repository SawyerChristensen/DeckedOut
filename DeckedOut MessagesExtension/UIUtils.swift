//
//  UIUtils.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 11/17/25.
//

import SwiftUI

extension Suit {
    var stringValue: String {
        switch self {
        case .spades: return "Spades"
        case .hearts: return "Hearts"
        case .diamonds: return "Diamonds"
        case .clubs: return "Clubs"
        }
    }
}

extension Rank {
    var stringValue: String {
        switch self {
        case .ace: return "ace"
        case .two: return "2"
        case .three: return "3"
        case .four: return "4"
        case .five: return "5"
        case .six: return "6"
        case .seven: return "7"
        case .eight: return "8"
        case .nine: return "9"
        case .ten: return "10"
        case .jack: return "jack"
        case .queen: return "queen"
        case .king: return "king"
        }
    }
}

extension Card {
    var imageName: String {
        "\(rank.stringValue)\(suit.stringValue)"
    }
}


struct CardView: View {
    let imageName: String
    let isFaceUp: Bool
    
    var body: some View {
        Image(isFaceUp ? imageName : "cardBackRed")
            .resizable()
            .aspectRatio(0.7, contentMode: .fit)
            .frame(height: 140)
            .shadow(radius: 3)
    }
}

struct FannedHandView: View {
    let cards: [Card]
    let isFaceUp: Bool
    
    var body: some View {
        HStack(spacing: -67) {
            ForEach(Array(cards.enumerated()), id: \.1) { index, card in
                CardView(imageName: card.imageName, isFaceUp: isFaceUp)
                    .rotationEffect(.degrees(Double(index - cards.count/2) * 4))
                    .offset(y: abs(Double(index - cards.count/2) * 5))
            }
        }
    }
}
