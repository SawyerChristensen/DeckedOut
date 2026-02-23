//
//  Crazy8sTranscriptPlayerHand.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 2/23/26.
//

import SwiftUI

struct Crazy8sTranscriptPlayerHand: View {
    let cards: [Card]
    let playerWon: Bool
    let opponentWon: Bool
    
    @State private var cardFlipTrigger: Bool = false
    @State private var cardsAreExpanded: Bool = false
    
    let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    let crazy8sTitle = ["C", "R", "A", "Z", "Y", "8", "S"]
    
    // Constants tuned for the small iMessage bubble
    private let cardWidth: CGFloat = 84 //120 * 0.7
    private let cardHeight: CGFloat = 120
    private var dynamicSpacing: CGFloat {
        let baseSpacing: CGFloat = -60
        if cards.count > 5 {
            let compression = CGFloat(cards.count - 5) * 2.0 ///Gradually tighten spacing as the hand grows
            return cardsAreExpanded ? (baseSpacing + 5 - compression) : (baseSpacing - compression)
        }
        return baseSpacing
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
