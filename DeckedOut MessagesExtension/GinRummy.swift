//
//  GinRummy.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 11/17/25.
//

import Foundation
import SwiftUI

struct GinGameView: View {
    let playerHand: [Card] = [
        .init(suit: .hearts, rank: .five),
        .init(suit: .hearts, rank: .six),
        .init(suit: .hearts, rank: .seven),
        
        .init(suit: .spades, rank: .seven),
        .init(suit: .diamonds, rank: .seven),
        .init(suit: .clubs, rank: .seven),

        .init(suit: .clubs, rank: .eight),
        .init(suit: .clubs, rank: .nine),
        .init(suit: .clubs, rank: .ten),
        .init(suit: .clubs, rank: .jack)
    ]
    let opponentHand: [Card] = [
        .init(suit: .hearts, rank: .five),
        .init(suit: .hearts, rank: .six),
        .init(suit: .hearts, rank: .seven),
        
        .init(suit: .spades, rank: .seven),
        .init(suit: .diamonds, rank: .seven),
        .init(suit: .clubs, rank: .seven),

        .init(suit: .clubs, rank: .eight),
        .init(suit: .clubs, rank: .nine),
        .init(suit: .clubs, rank: .ten),
        .init(suit: .clubs, rank: .jack)
    ]
    
    let discardTop: Card? = .init(suit: .hearts, rank: .ace)

    
    var body: some View {
        
        VStack {
            // Opponent's Hand
            FannedHandView(cards: opponentHand, isFaceUp: false)
                .rotationEffect(Angle(degrees: 180))
                .shadow(radius: 20)
                .padding(.top, 30)
            
            Spacer()
            
            // Middle section
            HStack {
                // Deck
                ZStack {
                    ForEach(0..<5) { i in
                        Image("cardBackRed")
                            .resizable()
                            .aspectRatio(0.7, contentMode: .fit)
                            .frame(height: 140)
                            .offset(x: CGFloat(-i) * 2, y: CGFloat(-i) * 2)
                            .shadow(radius: i == 4 ? 1 : 5)
                    }
                }
                .onTapGesture {
                    print("Draw from deck")
                }

                Spacer()

                // Discard Pile
                if let cardImage = discardTop?.imageName {
                    CardView(imageName: cardImage, isFaceUp: true)
                        .onTapGesture {
                            print("Draw from discard pile")
                        }
                        .shadow(radius: 5)
                }
            }
            .padding(.horizontal, 80)
            
            Spacer()
            
            // Player's hand
            FannedHandView(cards: playerHand, isFaceUp: true)
                .padding(.bottom, 40)
                .shadow(radius: 5)
                .offset(x: 10)
            
        }
        .background(Image("feltTexture")
            .luminanceToAlpha()
            //.blendMode(.multiply))
            .opacity(0.5))
        .background(Color(.green).opacity(0.75))
    }
}
