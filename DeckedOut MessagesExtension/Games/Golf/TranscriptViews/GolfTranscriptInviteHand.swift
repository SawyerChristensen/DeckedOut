//
//  GolfTranscriptInviteHand.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 4/15/26.
//

import SwiftUI

struct GolfTranscriptInviteHand: View {
    var words: [String] {
        // Get the user's top preferred language, default to English if unavailable
        let currentLanguage = Locale.preferredLanguages.first ?? "en"
        
        if currentLanguage.hasPrefix("zh-Hant") { // Traditional Chinese
            return ["讓我們", "一起玩", "高爾夫"]

        } else if currentLanguage.hasPrefix("zh-Hans") { // Simplified Chinese
            return ["让我们", "一起玩", "高尔夫"]

        } else if currentLanguage.hasPrefix("tr") { // Turkish
            return ["HADI", "GOLF", "OYNA"]

        } else if currentLanguage.hasPrefix("de") { // German
            return ["ZEIT", "FURS", "GOLF"]

        } else { // Default (English)
            return ["LETS", "PLAY", "GOLF"]
        }
    }
    
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
    
    var charCount: Int {
        words.map(\.count).max() ?? 0
    }
    
    var body: some View {
        HStack(spacing: charCount == 4 ? -30 : -25) {
            ForEach(0..<charCount, id: \.self) { index in
                
                // Calculate the Current Character (Front)
                let currentWord = words[currentWordIndex]
                let frontChar = getChar(from: currentWord, at: index)
                
                // Calculate the Next Character (Back)
                let nextIndex = (currentWordIndex + 1) % words.count
                let nextWord = words[nextIndex]
                let backChar = getChar(from: nextWord, at: index)
                
                let center = Double(charCount - 1) / 2.0
                
                LetterCardView(frontChar: frontChar, backChar: backChar, isFlipped: isFlipped)
                    .frame(width: cardWidth, height: cardHeight)
                    .zIndex(Double(index))
                    .rotationEffect(.degrees((Double(index) - center) * fanningAngle))
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
