//
//  Crazy8sOpponentHandView.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 2/23/26.
//

import SwiftUI

struct Crazy8sOpponentHandView: View {
    @EnvironmentObject var game: Crazy8sManager
    
    //Passed Arguments
    let cards: [Card]
    var discardPileZone: CGRect? = nil
    var deckZone: CGRect? = nil
    var sizeScale: CGFloat = 1.0
    var handRotation: Double = 0 // parent rotation in degrees (z-axis); used to correct animation offsets

    init(cards: [Card], discardPileZone: CGRect, deckZone: CGRect, sizeScale: CGFloat = 1.0, handRotation: Double = 0) {
        self.cards = cards
        self.discardPileZone = discardPileZone
        self.deckZone = deckZone
        self.sizeScale = sizeScale
        self.handRotation = handRotation
    }
    
    // For animating from deck/discard
    @State private var slotFrames: [Int: CGRect] = [:]
    @State private var animatingCard: Card?
    @State private var animationOffset: CGSize = .zero
    @State private var animationRotationCorrection: Angle = .zero
    @State private var animatingRotation: Double = 0 //for when the card is being animated
    @State private var normalRotation: Double = 180 //default to face down
    @State private var cardWaitingToAnimate: Card?
    @State private var animatingShadowRadius: CGFloat = 0
    @State private var animatingScaleCorrection: CGFloat = 1.0
    
    // Card sizing
    private var cardWidth: CGFloat { (cards.count >= 10 ? 98 : 101.5) * sizeScale }
    private var cardHeight: CGFloat { (cards.count >= 10 ? 140 : 145) * sizeScale }
    private var spacing: CGFloat { (cards.count >= 10 ? -72 : -66) * sizeScale }
    private var centerOffset: Double { Double(cards.count - 1) / 2.0 }
    private let fanningAngle: Double = 4
    
    var body: some View {
        RotatedHandLayout(
            rotation: .degrees(handRotation),
            spacing: spacing,
            sizeScale: sizeScale,
            cardWidth: cardWidth,
            cardHeight: cardHeight
        ) {
            ForEach(cards) { card in
                let isAnimating = (animatingCard == card)
                let index = cards.firstIndex(of: card)!
                let angle = Angle.degrees((Double(index) - centerOffset) * -fanningAngle)
                let revealRotation = game.opponentHasWon || game.playerHasWon ? 360 : normalRotation
                let restingRotation = angle + .degrees(handRotation)
                
                CardView(frontImage: card.imageName, cardHeight: cardHeight, rotation: isAnimating ? animatingRotation : revealRotation)
                    .scaleEffect(isAnimating ? animatingScaleCorrection : 1.0)
                    .zIndex(Double(index))
                    .opacity(cardWaitingToAnimate == card ? 0 : 1)
                    .rotationEffect(isAnimating ? animationRotationCorrection : restingRotation)
                    .offset(isAnimating ? animationOffset : .zero)
                    .shadow(color: .black.opacity(0.25), radius: isAnimating ? animatingShadowRadius : 20)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.1),
                        value: game.opponentHasWon || game.playerHasWon // trigger when this value changes
                    )
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: cards.count)
                    .background( // capture the global frame of this specific slot
                        GeometryReader { geo in
                            Color.clear
                                .onAppear { slotFrames[index] = geo.frame(in: .global) }
                                .onChange(of: geo.frame(in: .global)) { _, newFrame in
                                    slotFrames[index] = newFrame
                                }
                        }
                    )
                    .frame(width: cardWidth, height: cardHeight)
            }
        }
        .onChange(of: game.opponentCardAnimatingFromDeck) { _, card in
            guard let card = card else { return }
            guard let drawIndex = cards.firstIndex(of: card) else { return }
            
            cardWaitingToAnimate = card
            
            // Wait a frame for the GeometryReader to report the new slot's frame
            DispatchQueue.main.async {
                guard let targetFrame = slotFrames[drawIndex],
                      let zone = deckZone else {
                    cardWaitingToAnimate = nil
                    return
                }
                
                let exactCenterOffset = Double(cards.count - 1) / 2.0
                let finalAngle = Angle.degrees((Double(drawIndex) - exactCenterOffset) * -fanningAngle)
                
                self.animatingCard = card
                animateDraw(cardFrame: targetFrame, drawZone: zone, fanAngle: finalAngle)
            }
        }
        
        .onChange(of: game.opponentCardAnimatingToDiscard) { _, pendingCard in
            if let card = pendingCard, let discardedIndex = cards.firstIndex(of: card) {
                let discardFrame = slotFrames[discardedIndex] ?? deckZone ?? .zero
                
                // Use exact centerOffset here too!
                let exactCenterOffset = Double(cards.count - 1) / 2.0
                let discardAngle = Angle.degrees((Double(discardedIndex) - exactCenterOffset) * -fanningAngle)
                
                self.animatingCard = card
                animateDiscard(card: card, cardFrame: discardFrame, fanAngle: discardAngle)
            }
        }
    }
    
    private func animateDraw(cardFrame: CGRect, drawZone: CGRect, fanAngle: Angle) { //automatically calls the animateDiscard function as well...
        // Calculate offset from card's natural position to discard pile (in screen space)
        let offsetToDraw = CGSize(
                width: drawZone.midX - cardFrame.midX,
                height: drawZone.midY - cardFrame.midY + cardHeight/5)

        // initial state: card appears at full size at the deck (un-rotated on screen)
        animationOffset = offsetToDraw
        animatingRotation = 180
        animationRotationCorrection = .zero
        animatingShadowRadius = 0
        animatingScaleCorrection = 1.0 / sizeScale
        self.cardWaitingToAnimate = nil

        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            animationOffset = .zero
            animationRotationCorrection = fanAngle + .degrees(handRotation)
            animatingRotation = 180
            animatingShadowRadius = 20
            animatingScaleCorrection = 1.0
        }

        // Clear draw animation state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.animatingCard = nil
        }
    }
    
    private func animateDiscard(card: Card, cardFrame: CGRect, fanAngle: Angle) {
        // Calculate offset from card's natural position to discard pile (in screen space)
        let offsetToDiscard = CGSize(
            width: discardPileZone!.midX - cardFrame.midX,
            height: discardPileZone!.midY - cardFrame.midY
        )

        // initial state: card is at hand scale
        animatingRotation = -180 //card is face down
        animationOffset = .zero
        animationRotationCorrection = fanAngle + .degrees(handRotation)
        animatingShadowRadius = 20
        animatingScaleCorrection = 1.0

        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            animatingRotation = 0 //card gets discarded face up
            animationOffset = offsetToDiscard
            animationRotationCorrection = .zero
            animatingShadowRadius = 0
            animatingScaleCorrection = 1.0 / sizeScale
            game.activeSuitOverride = game.hiddenActiveSuitOverride
        }

        // Resolve animation state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            animatingCard = nil
            animationOffset = .zero
            game.opponentDiscardCard(card: card)
            game.opponentCardAnimatingToDiscard = nil
        }
    }
}


struct RotatedHandLayout: Layout {
    var rotation: Angle
    var spacing: CGFloat
    var sizeScale: CGFloat
    var cardWidth: CGFloat
    var cardHeight: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        // We report the base, un-rotated size to the parent.
        // The layout will naturally draw outside these bounds, which is standard for card UIs.
        let totalWidth = cardWidth + max(0, CGFloat(subviews.count - 1)) * (cardWidth + spacing)
        return CGSize(width: totalWidth, height: cardHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        
        let centerIndex = Double(subviews.count - 1) / 2.0
        let radians = rotation.radians
        let c = cos(radians)
        let s = sin(radians)
        
        for (index, subview) in subviews.enumerated() {
            // 1. Calculate base local layout (mimicking HStack + your arc yOffset)
            let baseX = (Double(index) - centerIndex) * Double(cardWidth + spacing)
            let baseY = -abs((Double(index) - centerIndex) * 5.0 * Double(sizeScale))
            
            // 2. Rotate coordinates mathematically
            let rotatedX = baseX * c - baseY * s
            let rotatedY = baseX * s + baseY * c
            
            // 3. Place exactly where it belongs inside the global frame
            let point = CGPoint(
                x: bounds.midX + CGFloat(rotatedX),
                y: bounds.midY + CGFloat(rotatedY)
            )
            
            subview.place(at: point, anchor: .center, proposal: ProposedViewSize(width: cardWidth, height: cardHeight))
        }
    }
}
