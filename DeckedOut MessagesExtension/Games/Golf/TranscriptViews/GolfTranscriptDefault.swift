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
    private var playerFaceUpIndices: Set<Int> {
        if isFromMe {
            var faceUp = gameState.senderFaceUpIndices
            if let idx = gameState.indexSenderReplaced { faceUp.insert(idx) }
            return faceUp
        } else {
            return gameState.receiverFaceUpIndices
        }
    }
    
    /// The sender's actual face-up count after their turn (pre-turn set + the replaced index)
    private var senderAllFaceUp: Bool {
        var faceUp = gameState.senderFaceUpIndices
        if let idx = gameState.indexSenderReplaced { faceUp.insert(idx) }
        return faceUp.count == 6
    }
    
    /// Game is over when the receiver had already gone out and the sender just took the final turn
    private var gameOver: Bool { gameState.receiverFaceUpIndices.count == 6 }
    
    private var playerWon: Bool {
        guard gameOver else { return false }
        return GolfManager.calculateScore(hand: playersHand) <= GolfManager.calculateScore(hand: opponentsHand)
    }
    private var opponentWon: Bool { gameOver && !playerWon }
    
    var body: some View {
        
        VStack {
            
            if playerWon || opponentWon {
                GameOverTranscriptView(playerWon: playerWon)
                
            } else {
                GolfTranscriptPlayerHand(cards: opponentWon ? opponentsHand : playersHand, faceUpIndices: playerFaceUpIndices)
                    .offset(y: 6)
                    .frame(height: 150)
            }
            
            CaptionTextView(isWaiting: isFromMe, altText: gameOver ? "You won in Golf!" : (senderAllFaceUp ? "Last turn in Golf!" : "Your turn in Golf!"))
            
        }
        .onAppear {
            if playerWon {
                WinTracker.shared.recordWinOnce(for: "Golf", sessionID: gameState.sessionID)
            }
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
