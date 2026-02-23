//
//  Crazys8TranscriptWaiting.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 2/23/26.
//

import SwiftUI

struct Crazys8TranscriptWaiting: View {
    let gameState: Crazy8sGameState
    let isFromMe: Bool
    var onHeightChange: ((CGFloat) -> Void)? = nil
    
    private var playersHand: [Card] { isFromMe ? gameState.senderHand : gameState.receiverHand }
    private var opponentsHand: [Card] { isFromMe ? gameState.receiverHand : gameState.senderHand }
    private var playerWon: Bool { playersHand.count == 0 }
    private var opponentWon: Bool { opponentsHand.count == 0 }
    
    var body: some View {
        VStack {
            
            Crazy8sTranscriptPlayerHand(cards: opponentWon ? opponentsHand : playersHand, playerWon: playerWon, opponentWon: opponentWon)
                .offset(y: opponentWon ? -30 : 50)
                .frame(height: 150)
                
            CaptionTextView(isWaiting: isFromMe, altText: opponentWon || playerWon ? "I won in Crazy 8s!" : "Your turn in Crazy 8s!")
            
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
