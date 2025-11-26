//
//  GinRummy.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 11/17/25.
//

import Foundation
import SwiftUI

enum Zone {
    case discard
    case hand
    case none
}

class DragState: ObservableObject {
    @Published var draggedCard: Card?
    @Published var dragLocation: CGPoint = .zero
    @Published var currentZone: Zone = .none
}

struct GinGameView: View {
    @EnvironmentObject var game: GameManager
    
    @State private var deckFrame: CGRect = .zero
    @State private var discardFrame: CGRect = .zero

    var body: some View {
        
        VStack {
            // Opponent's Hand
            FannedHandView(cards: game.opponentHand, isFaceUp: false)
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
                .background( // what defines the deck's zone
                    GeometryReader { geo in
                        Color.clear
                            .onAppear {
                                deckFrame = geo.frame(in: .global)
                            }
                            .onChange(of: geo.frame(in: .global)) { old, new in
                                deckFrame = new
                            }
                    }
                )

                Spacer()

                // Discard Pile
                if let cardImage = game.discardPile.first?.imageName {
                    CardView(imageName: cardImage, isFaceUp: true)
                        .onTapGesture {
                            print("Draw from discard pile")
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
            FannedHandView(cards: game.playerHand, isFaceUp: true,
                           onDragChanged: { card, location in handleDragChanged(card: card, location: location) },
                           onDragEnded: { card, location in handleDragEnded(card: card, location: location) }
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
            print("Hovering over DECK")
        } else if discardFrame.contains(location) {
            print("Hovering over DISCARD")
        } else {
            print("Hovering over nothing")
        }
    }

    func handleDragEnded(card: Card, location: CGPoint) {
        if deckFrame.contains(location) {
            print("DROP → Deck zone")
            //game.drawFromDeck(card)
        } else if discardFrame.contains(location) {
            print("DROP → Discard zone")
            //game.discard(card)
        } else {
            print("Drop → No zone, card returns")
        }
    }

}
