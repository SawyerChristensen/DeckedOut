//
//  Crazy8sTranscriptDefault.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 2/23/26.
//

import SwiftUI

struct Crazy8sTranscriptDefault: View {
    let gameState: Crazy8sGameState
    let isFromMe: Bool
    var onHeightChange: ((CGFloat) -> Void)? = nil
    @State private var initialBackgroundSize: CGSize = .zero //to prevent instant background resizing when Crazy8sTranscriptPlayerHand resizes beyond the current horizontal width

    private var playersHand: [Card] { isFromMe ? gameState.senderHand : gameState.receiverHand }
    private var opponentsHand: [Card] { isFromMe ? gameState.receiverHand : gameState.senderHand }
    private var playerWon: Bool { playersHand.count == 0 }
    private var opponentWon: Bool { opponentsHand.count == 0 }
    
    var body: some View {
        
        VStack {

            if playerWon || opponentWon {
                GameOverTranscriptView(playerWon: playerWon)
                
            } else {
                Crazy8sTranscriptPlayerHand(cards: playersHand)
                    .offset(y: opponentWon ? -30 : 50)
                    .frame(height: 150)
            }
                
            CaptionTextView(isWaiting: isFromMe, altText: opponentWon || playerWon ? "I won in Crazy 8s!" : "Your turn in Crazy 8s!")
            
        }
        .background( //for measuring & reporting the view height
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        if initialBackgroundSize == .zero {
                            initialBackgroundSize = geometry.size
                        }
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
                .frame(
                    width: initialBackgroundSize.width > 0 ? initialBackgroundSize.width : nil,
                    height: initialBackgroundSize.height > 0 ? initialBackgroundSize.height : nil
                )
        )
    }
}
