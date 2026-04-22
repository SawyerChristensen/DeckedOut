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
    private var playerFaceUpIndices: Set<Int> { isFromMe ? gameState.senderFaceUpIndices : gameState.receiverFaceUpIndices }
    
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
            
            if playerWon {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(LinearGradient(colors: [
                        Color(red: 1.0, green: 1.0, blue: 0.6), // Bright Yellow at the top
                        Color(red: 1.0, green: 0.8, blue: 0.33) // Orangish gold at the bottom
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                    ))
                    .shadow(color: .yellow, radius: 5, y: -4)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 6)
                    .padding(.top, 10)
                    .frame(height: 150)
                
            } else if opponentWon {
                Image(systemName: "xmark")
                    .font(.system(size: 90))
                    .fontWeight(.semibold)
                    .foregroundStyle(LinearGradient(colors: [
                        Color(red: 1.0, green: 0.4, blue: 0.4), // Bright red at the top
                        Color(red: 1.0, green: 0.0, blue: 0.0)  // Solid red at the bottom
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                    ))
                    .shadow(color: .red, radius: 10)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 6)
                    .padding(.top, 10)
                    .frame(height: 150)
                
            } else {
                GolfTranscriptPlayerHand(cards: opponentWon ? opponentsHand : playersHand, faceUpIndices: playerFaceUpIndices, playerWon: playerWon, opponentWon: opponentWon)
                    .offset(y: 6)
                    .frame(height: 150)
            }
            
            CaptionTextView(isWaiting: isFromMe, altText: gameOver ? "You won in Golf!" : (senderAllFaceUp ? "Last turn in Golf!" : "Your turn in Golf!"))
            
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
