//
//  Crazy8sTranscriptPlayerHand.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 2/23/26.
//

import SwiftUI
import Combine

struct Crazy8sTranscriptPlayerHand: View {
    let cards: [Card]
    
    var crazy8sTitle: [String] {
        let currentLanguage = Locale.preferredLanguages.first ?? "en"

        if currentLanguage.hasPrefix("zh-Hans") {
            return ["疯", "狂", "8"]
        } else if currentLanguage.hasPrefix("zh-Hant") {
            return ["瘋", "狂", "8"]
        } else if currentLanguage.hasPrefix("da") {
            return ["O", "L", "S", "E", "N"]
        } else if currentLanguage.hasPrefix("nl") {
            return ["P", "E", "S", "T", "E", "N"]
        } else if currentLanguage.hasPrefix("fr") {
            return ["8", "A", "M", "E", "R", "I", "C", "A", "I", "N"]
        } else if currentLanguage.hasPrefix("de") {
            return ["A", "C", "H", "T", "E", "N"]
        } else if currentLanguage.hasPrefix("hi") {
            return ["क्रे", "ज़ी", "8", "S"]
        } else if currentLanguage.hasPrefix("it") {
            return ["O", "T", "T", "O"]
        } else if currentLanguage.hasPrefix("ja") {
            return ["ク", "レ", "イ", "ジ", "ー", "エ", "イ", "ト"] //is this dash necessary?
        } else if currentLanguage.hasPrefix("ko") {
            return ["크", "레", "이", "지", "8"]
        } else if currentLanguage.hasPrefix("nb") {
            return ["V", "R", "I", "A", "T", "T", "E", "R"]
        } else if currentLanguage.hasPrefix("pt") {
            return ["O", "I", "T", "O", "M", "A", "L", "U", "C", "O"]
        } else if currentLanguage.hasPrefix("ru") {
            return ["В", "О", "С", "Ь", "М", "Ё", "Р", "К", "И"]
        } else if currentLanguage.hasPrefix("es") {
            return ["O", "C", "H", "O", "S", "L", "O", "C", "O", "S"]
        } else if currentLanguage.hasPrefix("sv") {
            return ["V", "A", "N", "D", "A", "T", "T", "A"]
        } else if currentLanguage.hasPrefix("tr") {
            return ["C", "I", "L", "G", "I", "N", "8", "L", "I"]
        } else { // Default (English)
            return ["C", "R", "A", "Z", "Y", "8", "S"]
        }
    }
    
    
    @State private var cardFlipTrigger: Bool = false
    @State private var cardsAreExpanded: Bool = false
    let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    
    // Constants tuned for the small iMessage bubble
    private let cardWidth: CGFloat = 84 //120 * 0.7
    private let cardHeight: CGFloat = 120
    private var dynamicSpacing: CGFloat {
        let baseSpacing: CGFloat = -55
        let expandAmount: CGFloat = 25.0
        if cards.count > 5 {
            let compression = CGFloat(cards.count - 5) * 2.0
            return baseSpacing - compression + (cardsAreExpanded ? expandAmount : 0)
        }
        return baseSpacing + (cardsAreExpanded ? expandAmount : 0)
    }
    private let fanningAngle: Double = 5.0

    var body: some View {
        HStack(spacing: dynamicSpacing) {
            ForEach(Array(cards.enumerated()), id: \.offset) { index, card in
                
                CardView(
                    frontImage: card.imageName,
                    backLetter: backLetter(for: index),
                    rotation: cardFlipTrigger ? 180.0 : 0.0
                )
                .frame(width: cardWidth, height: cardHeight)
                .zIndex(Double(index))
                .rotationEffect(angle(for: index))
                .offset(y: yOffset(for: index))
                .shadow(color: .black.opacity(0.15), radius: 10)
                .animation(
                    .spring(response: 0.6, dampingFraction: 0.7)
                    .delay(Double(index) * 0.2),
                    value: cardFlipTrigger
                )
            }
        }
        .offset(y: cardsAreExpanded ? -10 : 0)
        .animation(.spring(response: 0.8, dampingFraction: 1), value: cardsAreExpanded)
        .onReceive(timer) { _ in
            handleAnimationTriggers()
        }
    }
    
    // MARK: - Extracted Helper Methods
    private func centerOffset() -> Double {
        return Double(cards.count - 1) / 2.0
    }
    
    private func angle(for index: Int) -> Angle {
        let multiplier = Double(index) - centerOffset()
        return Angle.degrees(multiplier * fanningAngle)
    }
    
    private func yOffset(for index: Int) -> CGFloat {
        let multiplier = Double(index) - centerOffset()
        return CGFloat(abs(multiplier * 5.0))
    }
    
    private func backLetter(for index: Int) -> String? {
        guard index < crazy8sTitle.count else { return nil }
        return crazy8sTitle[index] ///Only return a letter for the first 7 cards
    }
    
    private func handleAnimationTriggers() {
        if !cardFlipTrigger {
            cardFlipTrigger = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                cardsAreExpanded = true
            }
        } else {
            cardsAreExpanded = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                cardFlipTrigger = false
            }
        }
    }
}
