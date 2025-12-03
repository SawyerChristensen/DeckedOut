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
    @State private var drewFromDeck: Bool = false

    var body: some View {
        
        VStack {
            // Opponent's Hand
            FannedHandView(cards: game.opponentHand, isFaceUp: false, drewFromDiscard: false, drewFromDeck: false)
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
                            .background {
                                if i == 4 { //4 is top card, the stack proceeds up-left, not down-right
                                    GeometryReader { geo in
                                        Color.clear
                                            .onAppear {
                                                deckFrame = calculateProperDeckZone(from: geo.frame(in: .global))
                                            }
                                            .onChange(of: geo.frame(in: .global)) { _, newFrame in
                                                deckFrame = calculateProperDeckZone(from: newFrame)
                                            }
                                    }
                                }
                            }
                    }
                }
                .onTapGesture {
                    game.drawFromDeck()
                    drewFromDeck = true
                }

            Spacer()

            // Discard Pile
            if let topCard = game.discardPile.first {
                CardView(imageName: topCard.imageName, isFaceUp: true)
                    .onTapGesture {
                        game.drawFromDiscard()
                        drewFromDiscard = true
                    }
                    .shadow(radius: 5)
                    .background( //what defines discard pile's zone
                        GeometryReader { geo in
                            Color.clear
                                .onAppear { discardFrame = geo.frame(in: .global) }
                                .onChange(of: geo.frame(in: .global)) { _, newFrame in
                                    discardFrame = newFrame
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
            deckZone: deckFrame,
            drewFromDiscard: drewFromDiscard,
            drewFromDeck: drewFromDeck,
            onDragChanged: { card, location in
                handleDragChanged(card: card, location: location)
            },
            onDragEnded: { card, location in
                handleDragEnded(card: card, location: location)
            }
        )
        .padding(.bottom, 40)
        .shadow(radius: 5)
        //.offset(x: 10)
        
    }
    .background(Image("feltTexture")
        .luminanceToAlpha()
        .opacity(0.5))
    .background(Color(.green).opacity(0.75))
}
    
    //MARK: - Game View Helper functions (technically global scope)
    func calculateProperDeckZone(from frame: CGRect) -> CGRect {
        var newFrame = frame
        let topIndex = 4
        let offsetPerCard: CGFloat = -2
        
        let totalOffset = CGFloat(topIndex) * offsetPerCard
        
        newFrame.origin.x += totalOffset
        newFrame.origin.y += totalOffset * 4.5
        
        return newFrame
    }
    
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
                game.discardCard(card: card)
            }
        } else {
            //print("Drop → No zone, card returns")
        }
    }

}
