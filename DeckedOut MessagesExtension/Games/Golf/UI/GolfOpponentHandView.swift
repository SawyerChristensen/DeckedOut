//
//  GolfOpponentHandView.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 4/15/26.
//

import SwiftUI

struct GolfOpponentHandView: View {
    @EnvironmentObject var game: GolfManager
    
    //Passed Arguments
    let cards: [Card]
    var faceUpIndices: Set<Int> = []
    var discardPileZone: CGRect? = nil
    var deckZone: CGRect? = nil
    
    init(cards: [Card], faceUpIndices: Set<Int>, discardPileZone: CGRect, deckZone: CGRect) {
        self.cards = cards
        self.faceUpIndices = faceUpIndices
        self.discardPileZone = discardPileZone
        self.deckZone = deckZone
    }
    
    // For animating departure and arrival
    @State private var slotFrames: [Int: CGRect] = [:]
    @State private var departingIndex: Int? = nil
    @State private var departingOffset: CGSize = .zero
    @State private var departingRotation: Double = 0
    @State private var arrivingCard: Card? = nil
    @State private var arrivingTargetIndex: Int? = nil
    @State private var arrivingOffset: CGSize = .zero
    @State private var arrivingRotation: Double = 0
    
    // Grid sizing (matches player hand)
    private let columns = 3
    private let rows = 2
    private let cardWidth: CGFloat = 91
    private let cardHeight: CGFloat = 130
    private let gridSpacingH: CGFloat = 24
    private let gridSpacingV: CGFloat = 12
    
    var body: some View {
        VStack(spacing: gridSpacingV) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: gridSpacingH) {
                    ForEach(0..<columns, id: \.self) { col in
                        let index = row * columns + col
                        
                        if index < cards.count {
                            let card = cards[index]
                            let isDeparting = (departingIndex == index)
                            let isArriving = (arrivingTargetIndex == index)
                            let isFaceUp = faceUpIndices.contains(index)
                            let revealAll = game.opponentHasWon || game.playerHasWon
                            
                            ZStack {
                                // Main card (departs to discard during animation)
                                CardView(frontImage: card.imageName,
                                         rotation: isDeparting ? departingRotation : (revealAll || isFaceUp ? 0 : -180))
                                    .shadow(color: game.opponentHasWon ? .red : .black.opacity(0.25),
                                            radius: game.opponentHasWon ? 10 : 5)
                                    .offset(isDeparting ? departingOffset : .zero)
                                
                                // Arriving card overlay (animates in from source)
                                if isArriving, let newCard = arrivingCard {
                                    CardView(frontImage: newCard.imageName, rotation: arrivingRotation)
                                        .shadow(color: .black.opacity(0.25), radius: 5)
                                        .offset(arrivingOffset)
                                }
                            }
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .onAppear { slotFrames[index] = geo.frame(in: .global) }
                                        .onChange(of: geo.frame(in: .global)) { _, newFrame in
                                            slotFrames[index] = newFrame
                                        }
                                }
                            )
                            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.1),
                                value: revealAll
                            )
                            .frame(width: cardWidth, height: cardHeight)
                            .zIndex(isDeparting || isArriving ? 100 : 0)
                        }
                    }
                }
            }
        }
        .frame(height: cardHeight * CGFloat(rows) + gridSpacingV)
        
        // Simultaneous departure + arrival animation
        .onChange(of: game.opponentDepartingFromIndex) { _, index in
            guard let index = index,
                  let slotFrame = slotFrames[index],
                  let discardZone = discardPileZone else { return }
            
            let source = game.drewFromDeck ? deckZone : discardPileZone
            guard let sourceZone = source else { return }
            
            // Peek at the arriving card before committing the swap
            let incomingCard = game.drewFromDeck ? game.deck.last : game.discardPile.last
            guard let newCard = incomingCard else { return }
            
            // Set initial states without animation
            let isFaceUp = faceUpIndices.contains(index)
            departingRotation = isFaceUp ? 0 : -180
            departingIndex = index
            arrivingCard = newCard
            arrivingTargetIndex = index
            arrivingRotation = game.drewFromDeck ? -180 : 0
            // Negate offsets because parent applies .rotationEffect(.degrees(180))
            arrivingOffset = CGSize(
                width: -(sourceZone.midX - slotFrame.midX),
                height: -(sourceZone.midY - slotFrame.midY)
            )
            
            // Animate both simultaneously on next run loop (ensures initial state renders first)
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    departingOffset = CGSize(
                        width: -(discardZone.midX - slotFrame.midX),
                        height: -(discardZone.midY - slotFrame.midY)
                    )
                    departingRotation = 0
                    arrivingOffset = .zero
                    arrivingRotation = 0
                }
            }
            
            // Commit the swap after animations complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                game.opponentReplaceCard()
                game.opponentDepartingFromIndex = nil
                departingIndex = nil
                departingOffset = .zero
                departingRotation = 0
                arrivingCard = nil
                arrivingTargetIndex = nil
                arrivingOffset = .zero
                arrivingRotation = 0
            }
        }
    }
}
