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
    /// The game's variant, from the payload. Drives which name is spelled across the card backs.
    var variant: Crazy8sVariant = .crazy8s
    private var crazy8sTitle: [String] { variant.titleLetters }
    
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
