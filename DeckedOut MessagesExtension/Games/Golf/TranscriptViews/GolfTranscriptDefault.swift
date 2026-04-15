//
//  GolfTranscriptDefault.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 4/15/26.
//

import SwiftUI

struct GolfTranscriptDefault: View {
    let gameState: GolfGameState
    let isFromMe: Bool
    var onHeightChange: ((CGFloat) -> Void)? = nil
    
    private var playersHand: [Card] { isFromMe ? gameState.senderHand : gameState.receiverHand }
    private var opponentsHand: [Card] { isFromMe ? gameState.receiverHand : gameState.senderHand }
    private var playerWon: Bool { false } //GolfValidator.canMeldAllCards(hand: playersHand) }
    private var opponentWon: Bool { false } //GolfValidator.canMeldAllCards(hand: opponentsHand) }
    
    var body: some View {
        VStack {
            
            GolfTranscriptPlayerHand(cards: opponentWon ? opponentsHand : playersHand, playerWon: playerWon, opponentWon: opponentWon)
                .offset(y: opponentWon ? -30 : 50)
                .frame(height: 150)
                
            CaptionTextView(isWaiting: isFromMe, altText: opponentWon || playerWon ? "I won in Golf!" : "Your turn in Golf!")
            
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
        .background(Image("feltBackgroundLight")
            .resizable()
            .aspectRatio(contentMode: .fill)
        )
    }
}
