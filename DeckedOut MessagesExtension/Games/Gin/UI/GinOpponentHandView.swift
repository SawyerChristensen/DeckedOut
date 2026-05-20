//
//  GinOpponentHandView.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 1/4/26.
//

import SwiftUI

struct GinOpponentHandView: View {
    @EnvironmentObject var game: GinRummyManager
    
    //Passed Arguments
    let cards: [Card]
    var discardPileZone: CGRect? = nil
    var deckZone: CGRect? = nil
    var sizeScale: CGFloat = 1.0
    var handRotation: Double = 0 // parent rotation in degrees (z-axis); used to correct animation offsets
    var cardBackName: String = "cardBackRed"

    init(cards: [Card], discardPileZone: CGRect, deckZone: CGRect, sizeScale: CGFloat = 1.0, handRotation: Double = 0, cardBackName: String = "cardBackRed") {
        self.cards = cards
        self.discardPileZone = discardPileZone
        self.deckZone = deckZone
        self.sizeScale = sizeScale
        self.handRotation = handRotation
        self.cardBackName = cardBackName
    }
    
    // For animating from deck/discard
    @State private var slotFrames: [Int: CGRect] = [:]
    @State private var animatingCard: Card?
    @State private var animationOffset: CGSize = .zero
    @State private var animationRotationCorrection: Angle = .zero
    @State private var animatingRotation: Double = 0 //for when the card is being animated
    @State private var normalRotation: Double = 180 //default to face down
    @State private var cardWaitingToAnimate: Card?
    @State private var winGlowRadius: CGFloat = 0
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
                
                CardView(frontImage: card.imageName, backImageName: cardBackName, cardHeight: cardHeight, rotation: isAnimating ? animatingRotation : revealRotation)
                    .scaleEffect(isAnimating ? animatingScaleCorrection : 1.0)
                    .zIndex(Double(index))
                    .opacity(cardWaitingToAnimate == card ? 0 : 1)
                    .rotationEffect(isAnimating ? animationRotationCorrection : restingRotation)
                    .offset(isAnimating ? animationOffset : .zero)
                    .shadow(color: game.opponentHasWon ? .red : .black.opacity(0.25), radius: game.opponentHasWon ? winGlowRadius : (isAnimating ? animatingShadowRadius : 20))
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
            }
            .frame(width: cardWidth, height: cardHeight)
        }
        .onAppear {
            if game.opponentHasWon {
                withAnimation(.linear(duration: 1)) {
                    winGlowRadius = 10
                }
            }
        }
        .onChange(of: game.opponentHasWon) { _, hasWon in
            if hasWon {
                withAnimation(.linear(duration: 0.33)) {
                    winGlowRadius = 10
                }
            } else { //is this else necessary? its initialized to 0 anyway
                winGlowRadius = 0
            }
        }
        .onChange(of: cards) { oldHand, newHand in
            if newHand.count > oldHand.count,
                let drawIndex = game.indexDrawnTo,
                drawIndex < newHand.count { //the opponent is drawing!
                guard animatingCard == nil else { return }

                let card = newHand[drawIndex]
                cardWaitingToAnimate = card
                
                DispatchQueue.main.async { //wait so slot frames can update!
                    guard let targetFrame = slotFrames[drawIndex],
                          let zone = game.opponentDrewFromDeck ? deckZone : discardPileZone else {
                        cardWaitingToAnimate = nil
                        return
                    }
                                  
                    
                    let card = newHand[drawIndex]
                    let finalAngle = Angle.degrees(Double(drawIndex - newHand.count/2) * -fanningAngle)
                    
                    self.animatingCard = card
                    animateDraw(cardFrame: targetFrame, drawZone: zone, fanAngle: finalAngle) { //trigger this after animateDraw...
                        
                        if let discardedIndex = game.indexDiscardedFrom {
                            if newHand.indices.contains(discardedIndex) {
                                let discardCard = newHand[discardedIndex]
                                let discardFrame = slotFrames[discardedIndex] ?? targetFrame
                                let discardAngle = Angle.degrees(Double(discardedIndex - newHand.count/2) * -fanningAngle)
                                
                                self.animatingCard = discardCard
                                animateDiscard(card: discardCard, cardFrame: discardFrame, fanAngle: discardAngle)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func animateDraw(cardFrame: CGRect, drawZone: CGRect, fanAngle: Angle, completion: @escaping () -> Void) { //automatically calls the animateDiscard function as well...
        // Calculate offset from card's natural position to discard pile
        let offsetToDraw: CGSize
        if game.opponentDrewFromDeck {
            offsetToDraw = CGSize(
                width: drawZone.midX - cardFrame.midX,
                height: drawZone.midY - cardFrame.midY + cardHeight/5) //cardHeight/5 is offseting how the deck is built stack is construction and just so happens to match well. will need to change this once the deck starts getting slimmed down
        } else {
            offsetToDraw = CGSize(
                width: drawZone.midX - cardFrame.midX,
                height: drawZone.midY - cardFrame.midY)
        }
        
        if !game.opponentDrewFromDeck { //they drew from discard, the card is face up
            animatingRotation = 0
        } else { animatingRotation = 180 } //they drew from the deck, the card is face down
        
        // initial state
        animationOffset = offsetToDraw
        animationRotationCorrection = .zero
        animatingShadowRadius = 0
        animatingScaleCorrection = 1.0 / sizeScale
        self.cardWaitingToAnimate = nil

        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            animationOffset = .zero
            animationRotationCorrection = fanAngle + .degrees(handRotation)
            animatingRotation = 180 //make sure the card is face down at end of animation
            animatingShadowRadius = 20
            animatingScaleCorrection = 1.0
        }
            
        // Clear draw animation state and call discard animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            completion()
        }
    }
    
    private func animateDiscard(card: Card, cardFrame: CGRect, fanAngle: Angle) {
        // Calculate offset from card's natural position to discard pile
        let offsetToDiscard = CGSize(
            width: discardPileZone!.midX - cardFrame.midX,
            height: discardPileZone!.midY - cardFrame.midY
        )

        // initial state
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
        }
            
        // Resolve animation state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            animatingCard = nil
            animationOffset = .zero
            game.opponentDiscardCard(card: card)
        }
    }
}
