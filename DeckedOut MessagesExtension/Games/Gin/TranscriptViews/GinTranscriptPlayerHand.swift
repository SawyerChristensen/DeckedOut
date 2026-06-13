//
//  GinTranscriptPlayerHand.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 2/1/26.
//

import SwiftUI

struct GinTranscriptPlayerHand: View {
    let cards: [Card]
    let playerWon: Bool
    let opponentWon: Bool
    var opponentCardBack: String? = nil

    @State private var cardFlipTrigger: Bool = false
    @State private var cardsAreExpanded: Bool = false
    
    let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    
    // Constants tuned for the small iMessage bubble
    private let cardWidth: CGFloat = 84 //120 * 0.7
    private let cardHeight: CGFloat = 120
    private var spacing: CGFloat {
        if cards.count == 7 {
            if cardsAreExpanded {
                return -55
            }
            return -60
        } else if cards.count == 10 {
            if cardsAreExpanded {
                return -58
            }
            return -63
        }
        return -60 //should never fire...
    }
    private let fanningAngle: Double = 5
    
    private var handHorizontalOffset: CGFloat {
        if cards.count == 10 {
            if cardsAreExpanded {
                return -13.0 // <- left
            }
            return 2.0 // right ->
        } //if cards.count == 7...
        return 0.0
    }
    private var handVerticalOffset: CGFloat {
        guard !opponentWon && cardsAreExpanded else { return 0.0 }
        if cards.count == 10 {
            return -10.0 //negative goes up
        } //if cards.count == 7...
        return -5.0
    }
    
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(Array(cards.enumerated()), id: \.offset) { index, card in
                
                CardView(
                    frontImage: card.imageName,
                    backLetter: backLetter(for: index),
                    backImageName: opponentWon ? opponentCardBack : nil,
                    rotation: currentRotation(for: index)
                )
                .frame(width: cardWidth, height: cardHeight)
                .zIndex(Double(opponentWon ? -index : index))
                .rotationEffect(opponentWon ? -angle(for: index) : angle(for: index))
                .offset(y: opponentWon ? -yOffset(for: index) : yOffset(for: index))
                .shadow(color: shadowColor, radius: 10)
                .animation(
                    .spring(response: 0.6, dampingFraction: 0.7)
                    .delay(Double(index) * 0.2),
                    value: cardFlipTrigger
                )
            }
        }
        .offset(x: handHorizontalOffset, y: handVerticalOffset)
        .animation(.spring(response: 0.8, dampingFraction: 1), value: cardsAreExpanded)
        .onReceive(timer) { _ in
            handleAnimationTriggers()
        }
    }
    
    // MARK: - Extracted Helper Methods
    
    private func centerOffset() -> Double {
        return cards.count == 7 ? 3.0 : 5
    }
    
    private func angle(for index: Int) -> Angle {
        let multiplier = Double(index) - centerOffset()
        return Angle.degrees(multiplier * fanningAngle)
    }
    
    private func yOffset(for index: Int) -> CGFloat {
        let multiplier = Double(index) - centerOffset()
        return CGFloat(abs(multiplier * 5.0))
    }
    
    private func isFullyFlippingCard(_ index: Int) -> Bool {
        if cards.count == 7 {
            return [1, 3, 5].contains(index)
        } else if cards.count == 10 {
            return [2, 4, 6, 8].contains(index)
        }
        return false
    }
    
    private func currentRotation(for index: Int) -> Double {
        guard cardFlipTrigger else { return 0.0 }
        return isFullyFlippingCard(index) ? 180.0 : 90.0
    }
    
    private var isChinese: Bool {
        let code = Locale.current.language.languageCode?.identifier
        return code == "zh" //both simplified and traditional use the same letters to describe Gin Rummy
    }

    private func backLetter(for index: Int) -> String? {
        let letters: [String] = isChinese ? ["金", "拉", "米"] : ["G", "I", "N"]

        if cards.count == 7 {
            switch index {
            case 1: return letters[0]
            case 3: return letters[1]
            case 5: return letters[2]
            default: return nil
            }
        } else if cards.count == 10 {
            switch index {
            case 2: return letters[0]
            case 4: return letters[1]
            case 6: return letters[2]
            case 8: return "!"
            default: return nil
            }
        }

        return nil
    }
    
    private var shadowColor: Color {
        if opponentWon {
            return Color("lossRed").opacity(0.8)
        } else if cardFlipTrigger {
            return .white.opacity(0.5)
        } else if playerWon {
            return Color("winYellow").opacity(0.8)
        } else {
            return .black.opacity(0.15)
        }
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
