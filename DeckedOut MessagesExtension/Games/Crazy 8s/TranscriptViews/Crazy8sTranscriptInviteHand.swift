//
//  Crazy8sTranscriptInviteHand.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 2/23/26.
//

import SwiftUI

struct Crazy8sTranscriptInviteHand: View {
    let words = ["LETS", "PLAY", "GIN!"] //FIX!!
    
    // State to track which word index we are on
    @State private var currentWordIndex = 0
    // State to drive the animation
    @State private var isFlipped = false
    
    // Timer
    let timer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()
    
    // Fanning Constants
    private let cardWidth: CGFloat = 84 //120 * 0.7
    private let cardHeight: CGFloat = 120
    private let fanningAngle: Double = 5
    
    var body: some View {
        HStack(spacing: -30) {
            ForEach(0..<4, id: \.self) { index in
                
                // Calculate the Current Character (Front)
                let currentWord = words[currentWordIndex]
                let frontChar = getChar(from: currentWord, at: index)
                
                // Calculate the Next Character (Back)
                let nextIndex = (currentWordIndex + 1) % 3
                let nextWord = words[nextIndex]
                let backChar = getChar(from: nextWord, at: index)
                
                LetterCardView(frontChar: frontChar, backChar: backChar, isFlipped: isFlipped)
                    .frame(width: cardWidth, height: cardHeight)
                    .zIndex(Double(index))
                    .rotationEffect(.degrees((Double(index) - 1.5) * fanningAngle))
                    .offset(y: abs((Double(index) - 1.5) * 8))
                    .animation(
                        .spring(response: 0.6, dampingFraction: 0.7)
                        .delay(Double(index) * 0.2),
                        value: isFlipped
                    )
            }
        }
        .onReceive(timer) { _ in
            cycleWords()
        }
    }
    
    func cycleWords() {
        // 1. Trigger the Flip Animation (Front -> Back)
        isFlipped = true
        
        // 2. Wait for animation to finish, then reset instantly
        // The delay here should match animation duration + stagger
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            
            // Disable animation for the reset to make it instant
            var transaction = Transaction()
            transaction.disablesAnimations = true
            
            withTransaction(transaction) {
                // RESET: Move to next word index
                currentWordIndex = (currentWordIndex + 1) % words.count
                
                // RESET: Snap rotation back to 0
                // Because we advanced the index, the "Front" is now what the "Back" used to be.
                // The user sees no visual change, but the card is reset for the next flip.
                isFlipped = false
            }
        }
    }
    
    func getChar(from word: String, at index: Int) -> String { //do we really need this?
        let chars = Array(word)
        if index < chars.count {
            return String(chars[index])
        }
        return " "
    }
}
