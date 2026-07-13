//
//  Crazy8sTranscriptInviteHand.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 2/23/26.
//

import SwiftUI
import Combine

struct Crazy8sTranscriptInviteHand: View {
    var cardBackName: String? = nil
    /// The game's variant, from the payload. Drives which name is spelled across the card backs.
    var variant: Crazy8sVariant = .crazy8s

    var words: [String] { variant.titleWords }
    
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
    
    var charCount: Int {
        words.map(\.count).max() ?? 0
    }

    // Fan spacing: a comfortable baseline for short titles (≤ 4 cards), then a damper that
    // pulls the cards tighter for every extra card so longer titles still fit the bubble.
    private var spacing: CGFloat {
        let baseSpacing: CGFloat = -25   // spacing for 4 cards or fewer
        let damperPerCard: CGFloat = 5   // extra compression for each card beyond 4
        let extraCards = max(0, charCount - 4)
        return baseSpacing - CGFloat(extraCards) * damperPerCard
    }

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<charCount, id: \.self) { index in
                
                // Calculate the Current Character (Front)
                let currentWord = words[currentWordIndex]
                let frontChar = getChar(from: currentWord, at: index)
                
                // Calculate the Next Character (Back)
                let nextIndex = (currentWordIndex + 1) % words.count
                let nextWord = words[nextIndex]
                let backChar = getChar(from: nextWord, at: index)
                
                let center = Double(charCount - 1) / 2.0
                
                LetterCardView(frontChar: frontChar, backChar: backChar, isFlipped: isFlipped, cardBackName: cardBackName)
                    .frame(width: cardWidth, height: cardHeight)
                    .zIndex(Double(index))
                    .rotationEffect(.degrees((Double(index) - center) * fanningAngle)) //replace 1.5 with double(currentWord.length / 2)
                    .offset(y: abs((Double(index) - center) * 8))
                    .animation(
                        .spring(response: 0.6, dampingFraction: 0.88)
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
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
