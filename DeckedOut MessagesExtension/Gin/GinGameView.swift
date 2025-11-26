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
                if let cardImage = game.discardPile.first?.imageName {
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
            FannedHandView(cards: game.playerHand, isFaceUp: true)
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
