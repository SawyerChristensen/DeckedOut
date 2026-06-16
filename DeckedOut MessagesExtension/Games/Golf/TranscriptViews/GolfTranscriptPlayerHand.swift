//
//  GolfTranscriptPlayerHand.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 4/15/26.
//

import SwiftUI
import Combine

struct GolfTranscriptPlayerHand: View {
    let cards: [Card]
    let faceUpIndices: Set<Int>
    
    @State private var cardFlipTrigger: Bool = false
    
    let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    
    // Constants tuned for the small iMessage bubble
    private let cardWidth: CGFloat = 77 //110 * 0.7
    private let cardHeight: CGFloat = 110
    private let columns = 3
    private let rows = 2
    private let horizontalSpacing: CGFloat = 12
    private let verticalSpacing: CGFloat = 10
    
    
    var body: some View {
        VStack(spacing: verticalSpacing) {
            ForEach(0..<2, id: \.self) { row in
                HStack(spacing: horizontalSpacing) {
                    ForEach(0..<3, id: \.self) { col in
                        let cardIndex = (row * 3) + col
                        let card = cards[cardIndex]
                        
                        CardView(
                            frontImage: card.imageName,
                            backLetter: backLetter(for: cardIndex),
                            rotation: currentRotation(for: cardIndex)
                        )
                        .frame(width: cardWidth, height: cardHeight)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: cardFlipTrigger)
                    }
                }
            }
        }
        //.onReceive(timer) { _ in
        //    cardFlipTrigger.toggle()
        //}
    }
    
    // MARK: - Helper Methods
    private func currentRotation(for index: Int) -> Double {
        let isRevealed = faceUpIndices.contains(index)
        //let showFront = isRevealed && cardFlipTrigger
        
        return isRevealed ? 0.0 : 180.0
    }
    
    private func backLetter(for index: Int) -> String? {
        return nil
    }
}
