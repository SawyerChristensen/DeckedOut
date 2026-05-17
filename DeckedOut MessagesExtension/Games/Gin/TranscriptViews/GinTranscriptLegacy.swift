//
//  GinTranscriptLegacy.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 2/1/26.
//

import SwiftUI

struct GinTranscriptLegacy: View {
    let gameState: GinRummyGameState
    let isFromMe: Bool
    var onHeightChange: ((CGFloat) -> Void)? = nil
    
    private var playersHand: [Card] { isFromMe ? gameState.senderHand : gameState.receiverHand }
    private var opponentsHand: [Card] { isFromMe ? gameState.receiverHand : gameState.senderHand }
    private var playerWon: Bool { GinRummyValidator.canMeldAllCards(hand: playersHand) }
    private var opponentWon: Bool { GinRummyValidator.canMeldAllCards(hand: opponentsHand) }
    
    var body: some View {
        VStack {
            
            Color.clear
                .frame(height: 150)
                .overlay { //the crazy 8s player hand expands. making it an overlay means its width expansion does not bubble up and effect the VStacks width
                    GinTranscriptPlayerHand(cards: opponentWon ? opponentsHand : playersHand, playerWon: playerWon, opponentWon: opponentWon)
                        .offset(y: opponentWon ? -30 : 50)
                }
                
            CaptionTextView(isWaiting: isFromMe, altText: opponentWon || playerWon ? "I won in Gin!" : "Your turn in Gin!")
            
        }
        .background( //for measuring & reporting the view height
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        onHeightChange?(geometry.size.height)
                    }
                    .onChange(of: geometry.size.height) { _, newHeight in
                        onHeightChange?(newHeight)
                    }
            }
        )
        .background(
            Image("feltBackgroundLight")
                .resizable()
                .aspectRatio(contentMode: .fill)
            )
    }
}
