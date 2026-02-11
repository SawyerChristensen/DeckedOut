//
//  TranscriptHandView.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 2/1/26.
//

import SwiftUI

struct TranscriptPlayerHandView: View {
    let cards: [Card]
    let playerWon: Bool
    let opponentWon: Bool
    
    @State private var cardFlipTrigger: Bool = false
    @State private var cardsAreExpanded: Bool = false
    
    let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    
    // Constants tuned for the small iMessage bubble
    private let cardWidth: CGFloat = 120 * 0.7
    private let cardHeight: CGFloat = 120
    //private let cardSpacing: CGFloat = -60
    private let fanningAngle: Double = 4
    
    var body: some View {
        HStack(spacing: cardsAreExpanded ? -55 : -60) {
            ForEach(Array(cards.enumerated()), id: \.offset) { index, card in
            
                let angle = Angle.degrees(Double(index - cards.count/2) * fanningAngle)
                let yOffset = abs(Double(index - cards.count / 2) * 5)
                let cardFlipsCompletely =   ([7, 8].contains(cards.count) && [1, 3, 5].contains(index)) ||
                                            ([10, 11].contains(cards.count) && [2, 4, 6, 8].contains(index))
                let currentRotation = cardFlipTrigger ? (cardFlipsCompletely ? 180.0 : 90.0) : 0
                let backLetter: String? = {
                    switch index {
                    case 1: return "G"
                    case 2: return "G"
                    case 3: return "I"
                    case 4: return "I"
                    case 5: return "N"
                    case 6: return "N"
                    case 8: return "!"
                    default: return nil
                    }
                }()
                
                CardView(frontImage: card.imageName, rotation: currentRotation, backLetter: backLetter)
                    .frame(width: cardWidth, height: cardHeight)
                    .zIndex(Double(opponentWon ? -index : index))
                    .rotationEffect(opponentWon ? -angle : angle)
                    .offset(y: opponentWon ? -yOffset : yOffset)
                    .shadow(color:  opponentWon ? .red.opacity(0.8) :
                                (cardFlipTrigger ? .white.opacity(0.5) :
                                    (playerWon ? .yellow.opacity(0.8) : .black.opacity(0.15))), //a little too elaborate but it works
                            radius: 10) //figure out shadow compatibility with animation
                    .animation(
                        .spring(response: 0.6, dampingFraction: 0.7)
                        .delay(Double(index) * 0.2), //or "dampingFraction: cardFlipTrigger ? 1 : 0.7)"
                        value: cardFlipTrigger
                    )
            }
        }
        .animation(.spring(response: 0.8, dampingFraction: 1), value: cardsAreExpanded)
        .onReceive(timer) { _ in
            handleAnimationTriggers()
        }
    }
    
    private func handleAnimationTriggers() {
        if !cardFlipTrigger {
            cardFlipTrigger = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                cardsAreExpanded = true }
            
        } else {
            cardsAreExpanded = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                cardFlipTrigger = false }
        }
    }
}
