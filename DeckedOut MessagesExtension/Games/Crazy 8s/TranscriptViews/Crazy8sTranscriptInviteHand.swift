//
//  Crazy8sTranscriptInviteHand.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 2/23/26.
//

import SwiftUI

struct Crazy8sTranscriptInviteHand: View {
    let words = ["CRAZY", "EIGHT"]
    
    // State to track which word index we are on
    @State private var currentWordIndex = 0
    // State to drive the animation
    @State private var isFlipped = false
    
    // Timer
    let timer = Timer.publish(every: 3.0, on: .main, in: .common).autoconnect()
    
    // Fanning Constants
    private let cardWidth: CGFloat = 84 //120 * 0.7
    private let cardHeight: CGFloat = 120
    private let fanningAngle: Double = 5
    
    var body: some View {
        HStack(spacing: -30) {
            ForEach(0..<5, id: \.self) { index in
                
                // Calculate the Current Character (Front)
                let currentWord = words[currentWordIndex]
                let frontChar = getChar(from: currentWord, at: index)
                
                // Calculate the Next Character (Back)
                let nextIndex = (currentWordIndex + 1) % 2
                let nextWord = words[nextIndex]
                let backChar = getChar(from: nextWord, at: index)
                
                LetterCardView(frontChar: frontChar, backChar: backChar, isFlipped: isFlipped)
                    .frame(width: cardWidth, height: cardHeight)
                    .zIndex(Double(index))
                    .rotationEffect(.degrees((Double(index) - 2.0) * fanningAngle)) //replace 1.5 with double(currentWord.length / 2)
                    .offset(y: abs((Double(index) - 2.0) * 8))
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
        // Trigger the Flip Animation (Front -> Back)
        isFlipped = true
        
        // Wait for animation to finish, then reset instantly
        // The delay here should match animation duration + stagger
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
            var transaction = Transaction()// Disable animation for the reset to make it instant
            transaction.disablesAnimations = true
            
            withTransaction(transaction) {
                currentWordIndex = (currentWordIndex + 1) % words.count
                isFlipped = false
            }
        }
    }
    
    func getChar(from word: String, at index: Int) -> String {
        let chars = Array(word)
        if index < chars.count {
            return String(chars[index])
        }
        return " "
    }
}
