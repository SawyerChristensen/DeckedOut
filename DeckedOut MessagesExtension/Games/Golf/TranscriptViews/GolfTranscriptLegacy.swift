//
//  GolfTranscriptLegacy.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 4/15/26.
//

import SwiftUI

struct GolfTranscriptLegacy: View {
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
        
        let playerScore = GolfManager.calculateScore(hand: playersHand)
        let opponentScore = GolfManager.calculateScore(hand: opponentsHand)
        if isFromMe {
            return playerScore <= opponentScore
        } else {
            return playerScore < opponentScore
        }
    }
    
    private var winMessage: String {
        return isFromMe == playerWon ? "I won in Golf!" : "You won in Golf!"
    }
    
    // MARK: - The Transcript View
    var body: some View {
        VStack {
            
            if gameOver {
                GameOverTranscriptView(playerWon: playerWon)
                
            } else {
                GolfTranscriptPlayerHand(cards: playersHand, faceUpIndices: playerFaceUpIndices)
                    .offset(y: 6)
                    .frame(height: 150)
            }
            
            CaptionTextView(isWaiting: isFromMe, altText: gameOver ? winMessage : (senderAllFaceUp ? "Last turn in Golf!" : "Your turn in Golf!"))
            
        }
        .onAppear {
            if playerWon {
                WinTracker.shared.recordWinOnce(for: "Golf", sessionID: gameState.sessionID)
                //GameCenterManager.shared.reportWin(firstWin: .firstWinGolf)
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
        .background(FeltBackgroundView())
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text("Golf", comment: "VoiceOver accessibility label for the Golf game transcript bubble"))
        .accessibilityInputLabels([
            Text("Golf", comment: "Voice Control input label – Golf game transcript bubble"),
            Text("Card Game", comment: "Voice Control input label – generic phrase for a card game"),
            Text("Golf game", comment: "Voice Control input label – Golf game transcript bubble"),
            Text("Golf card game", comment: "Voice Control input label – Golf game transcript bubble"),
            Text("Open card game", comment: "Voice Control input label – open the card game from the transcript bubble"),
        ])
    }
}
