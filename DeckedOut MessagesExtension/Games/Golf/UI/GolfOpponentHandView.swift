//
//  GolfOpponentHandView.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 4/15/26.
//

import SwiftUI

struct GolfOpponentHandView: View {
    @EnvironmentObject var game: GolfManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motionSpeed: Double { reduceMotion ? 0.66 : 1.0 } //animations should run at 2/3 speed when "Reduce Motion" is enabled

    //Passed Arguments
    let cards: [Card]
    var faceUpIndices: Set<Int> = []
    var discardPileZone: CGRect? = nil
    var deckZone: CGRect? = nil
    var sizeScale: CGFloat = 1.0
    var handRotation: Double = 0 // parent rotation in degrees (z-axis); used to correct animation offsets
    var cardBackName: String = "cardBackRed"

    init(cards: [Card], faceUpIndices: Set<Int>, discardPileZone: CGRect, deckZone: CGRect, sizeScale: CGFloat = 1.0, handRotation: Double = 0, cardBackName: String = "cardBackRed") {
        self.cards = cards
        self.faceUpIndices = faceUpIndices
        self.discardPileZone = discardPileZone
        self.deckZone = deckZone
        self.sizeScale = sizeScale
        self.handRotation = handRotation
        self.cardBackName = cardBackName
    }
    
    // For animating departure and arrival
    @State private var slotFrames: [Int: CGRect] = [:]
    @State private var departingIndex: Int? = nil
    @State private var departingOffset: CGSize = .zero
    @State private var departingRotation: Double = 0
    @State private var departingScale: CGFloat = 1.0
    @State private var departingCardImage: String? = nil //not completely sure why this is here
    @State private var arrivingCard: Card? = nil
    @State private var arrivingTargetIndex: Int? = nil
    @State private var arrivingOffset: CGSize = .zero
    @State private var arrivingRotation: Double = 0
    @State private var arrivingScale: CGFloat = 1.0
    @State private var winGlowRadius: CGFloat = 0
    
    // Grid sizing (matches player hand)
    private let columns = 3
    private let rows = 2
    private var cardWidth: CGFloat { 91 * sizeScale }
    private var cardHeight: CGFloat { 130 * sizeScale }
    private var gridSpacingH: CGFloat { 24 * sizeScale }
    private var gridSpacingV: CGFloat { 12 * sizeScale }
    
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
                            let isCancelled = game.opponentCancelledIndices.contains(index)
                            
                            ZStack {
                                // Main card (departs to discard during animation)
                                CardView(frontImage: isDeparting ? (departingCardImage ?? card.imageName) : card.imageName,
                                         backImageName: cardBackName,
                                         rotation: isDeparting ? departingRotation : (revealAll || isFaceUp ? 0 : -180))
                                    .shadow(color: game.opponentHasWon ? Palette.lossRed : .clear, radius: winGlowRadius)
                                    .shadow(color: game.opponentHasWon ? Palette.lossRed.opacity(0.5) : .clear, radius: winGlowRadius) //for extra red intensity
                                    .opacity(isCancelled ? 0.8 : 1.0)
                                    .animation(.easeInOut(duration: 0.3).speed(motionSpeed), value: isCancelled)
                                    .scaleEffect(isDeparting ? departingScale : 1.0)
                                    .offset(isDeparting ? departingOffset : .zero)
                                
                                // Arriving card overlay (animates in from source)
                                if isArriving, let newCard = arrivingCard {
                                    CardView(frontImage: newCard.imageName, backImageName: cardBackName, rotation: arrivingRotation)
                                        .shadow(color: .black.opacity(0.25), radius: 5)
                                        .scaleEffect(arrivingScale)
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
                            .animation(
                                isDeparting ? nil : .spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.1).speed(motionSpeed),
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
        .onAppear {
            if game.opponentHasWon {
                withAnimation(.linear(duration: 0.67).speed(motionSpeed)) {
                    winGlowRadius = 10
                }
            }
        }
        .onChange(of: game.opponentHasWon) { _, hasWon in
            if hasWon {
                withAnimation(.linear(duration: 0.33).speed(motionSpeed)) {
                    winGlowRadius = 10
                }
            } else { //is this else necessary? its initialized to 0 anyway
                winGlowRadius = 0
            }
        }
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
            departingCardImage = cards[index].imageName
            departingRotation = isFaceUp ? 0 : -180
            departingIndex = index
            departingScale = 1.0 // starts at hand size
            arrivingCard = newCard
            arrivingTargetIndex = index
            arrivingRotation = game.drewFromDeck ? -180 : 0
            arrivingScale = 1.0 / sizeScale // starts at deck/discard (canonical) size
            let screenDeltaArriving = CGSize(
                width: sourceZone.midX - slotFrame.midX,
                height: sourceZone.midY - slotFrame.midY
            )

            let screenDeltaDeparting = CGSize(
                width: discardZone.midX - slotFrame.midX,
                height: discardZone.midY - slotFrame.midY
            )
            arrivingOffset = toLocalOffset(screenDeltaArriving)
            
            // Animate both simultaneously on next run loop (ensures initial state renders first)
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7).speed(motionSpeed)) {
                    departingOffset = toLocalOffset(screenDeltaDeparting)
                    departingRotation = 0
                    departingScale = 1.0 / sizeScale // grows to discard (canonical) size
                    arrivingOffset = .zero
                    arrivingRotation = 0
                    arrivingScale = 1.0 // shrinks to hand size
                }
            }

            // Commit the swap after animations complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55 / motionSpeed) {
                game.opponentReplaceCard()
                game.opponentDepartingFromIndex = nil
                
                // Clean up animation state in the next run loop cycle.
                DispatchQueue.main.async {
                    departingIndex = nil
                    departingOffset = .zero
                    departingRotation = 0
                    departingScale = 1.0
                    departingCardImage = nil
                    arrivingCard = nil
                    arrivingTargetIndex = nil
                    arrivingOffset = .zero
                    arrivingRotation = 0
                    arrivingScale = 1.0
                }
            }
        }
    }
    
    // Convert a screen-space delta into this view's pre-rotation local space.
    // .offset() is applied before .rotationEffect, so the local delta rotated by `handRotation`
    // must equal the desired screen-space delta. With handRotation = 0 (the golf grid case)
    // this reduces to the identity.
    private func toLocalOffset(_ screenDelta: CGSize) -> CGSize {
        let radians = handRotation * .pi / 180
        let c = cos(radians)
        let s = sin(radians)
        return CGSize(
            width: screenDelta.width * c + screenDelta.height * s,
            height: -screenDelta.width * s + screenDelta.height * c
        )
    }
}
