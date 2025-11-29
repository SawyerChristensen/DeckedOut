//
//  GinRummy.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 11/17/25.
//

import Foundation
import SwiftUI

struct GinGameView: View {
    @EnvironmentObject var game: GameManager
    
    @State private var deckFrame: CGRect = .zero
    @State private var discardFrame: CGRect = .zero
    @State private var drewFromDiscard: Bool = false
    

    var body: some View {
        
        VStack {
            // Opponent's Hand
            FannedHandView(cards: game.opponentHand, isFaceUp: false, drewFromDiscard: false)
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
                            .frame(height: 145)
                            .offset(x: CGFloat(-i) * 2, y: CGFloat(-i) * 2)
                            .shadow(radius: i == 4 ? 1 : 5)
                    }
                }
                .onTapGesture {
                    print("Draw from deck")
                }

            Spacer()

            // Discard Pile
            if let topCard = game.discardPile.first {
                CardView(imageName: topCard.imageName, isFaceUp: true)
                    .onTapGesture {
                        print("User drew from discard pile")
                        game.drawFromDiscard()
                        drewFromDiscard = true
                    }
                    .shadow(radius: 5)
                    .background( //what defines discard pile's zone
                        GeometryReader { geo in
                            Color.clear
                                .onAppear { discardFrame = geo.frame(in: .global) }
                                .onChange(of: geo.frame(in: .global)) { old, new in
                                    discardFrame = new
                                }
                        }
                    )
            }
        }
        .padding(.horizontal, 80)
        
        
        Spacer()
        
        
        // Player's hand
        FannedHandView(
            cards: $game.playerHand,
            isFaceUp: true,
            discardPileZone: discardFrame,
            drewFromDiscard: drewFromDiscard,
            onDragChanged: { card, location in
                handleDragChanged(card: card, location: location)
            },
            onDragEnded: { card, location in
                handleDragEnded(card: card, location: location)
            }
        )
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
    
    
    //MARK: - Helper functions
    func handleDragChanged(card: Card, location: CGPoint) {
        if deckFrame.contains(location) {
            //print("Hovering over DECK")
        } else if discardFrame.contains(location) {
            //print("Hovering over DISCARD")
        } else {
            //print("Hovering over nothing")
        }
    }

    func handleDragEnded(card: Card, location: CGPoint) {
        if discardFrame.contains(location) {
            withAnimation(.spring(response: 0.3)) {
                if let index = game.playerHand.firstIndex(of: card) {
                    game.playerHand.remove(at: index)
                }
                
                game.discardPile.insert(card, at: 0)
            }
            
        } else {
            //print("Drop → No zone, card returns")
        }
    }

}
