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
    
    init(cards: [Card], discardPileZone: CGRect, deckZone: CGRect) {
        self.cards = cards
        self.discardPileZone = discardPileZone
        self.deckZone = deckZone
    }
    
    // For animating from deck/discard
    @State private var slotFrames: [Int: CGRect] = [:]
    @State private var animatingCard: Card?
    @State private var animationOffset: CGSize = .zero
    @State private var animationRotationCorrection: Angle = .zero
    @State private var animatingRotation: Double = 0 //for when the card is being animated
    @State private var normalRotation: Double = 180 //default to face down
    @State private var cardWaitingToAnimate: Card?
    
    // Card sizing
    private var cardWidth: CGFloat { cards.count >= 10 ? 98 : 101.5 }
    private var cardHeight: CGFloat { cards.count >= 10 ? 140 : 145 }
    private var spacing: CGFloat { cards.count >= 10 ? -72 : -66 } 
    private var centerOffset: Double { Double(cards.count - 1) / 2.0 }
    private let fanningAngle: Double = 4
    
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(cards) { card in
                let isAnimating = (animatingCard == card)
                let index = cards.firstIndex(of: card)!
                let angle = Angle.degrees((Double(index) - centerOffset) * -fanningAngle)
                let yOffset = -abs((Double(index) - centerOffset) * 5)
                let revealRotation = game.opponentHasWon || game.playerHasWon ? 360 : normalRotation
                
                CardView(frontImage: card.imageName, rotation: isAnimating ? animatingRotation : revealRotation)
                    .zIndex(Double(index))
                    .opacity(cardWaitingToAnimate == card ? 0 : 1)
                    .rotationEffect(isAnimating ? animationRotationCorrection : angle)
                    .offset(y: yOffset)
                    .offset(isAnimating ? animationOffset : .zero)
                    .shadow(color: game.opponentHasWon ? .red : .black.opacity(0.25), radius: game.opponentHasWon ? 10 : (isAnimating ? 0 : 20))
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.1),
                        value: game.opponentHasWon || game.playerHasWon // trigger when this value changes
                    )
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
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: cards.count)
        }
        .frame(height: cardHeight) //technically should be adding the arch amount but this doesnt really matter...
        
        .onChange(of: cards) { oldHand, newHand in
            if newHand.count > oldHand.count {
                let drawIndex = newHand.count - 1 // Safely get the new card's index
                guard animatingCard == nil else { return }
                
                let card = newHand[drawIndex]
                cardWaitingToAnimate = card
                
                DispatchQueue.main.async {
                    guard let targetFrame = slotFrames[drawIndex],
                          let zone = deckZone else {
                        cardWaitingToAnimate = nil
                        return
                    }
                    
                    let exactCenterOffset = Double(newHand.count - 1) / 2.0
                    let finalAngle = Angle.degrees((Double(drawIndex) - exactCenterOffset) * -fanningAngle)
                    
                    self.animatingCard = card
                    animateDraw(cardFrame: targetFrame, drawZone: zone, fanAngle: finalAngle)
                }
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
        // Calculate offset from card's natural position to discard pile
        let offsetToDraw = CGSize(
                width: drawZone.midX - cardFrame.midX,
                height: drawZone.midY - cardFrame.midY + cardHeight/4) //cardHeight/4 is offseting how the deck is built stack is construction and just so happens to match well. will need to change this once the deck starts getting slimmed down
        
        // initial state
        animationOffset = offsetToDraw
        animatingRotation = 0
        animationRotationCorrection = .degrees(0)
        self.cardWaitingToAnimate = nil
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            animationOffset = .zero
            animationRotationCorrection = fanAngle
            animatingRotation = 180
        }
            
        // Clear draw animation state and call discard animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            self.animatingCard = nil
        }
    }
    
    private func animateDiscard(card: Card, cardFrame: CGRect, fanAngle: Angle) {
        // Calculate offset from card's natural position to discard pile
        let cardIndex = cards.firstIndex(of: card)
        let yArcOffset = abs(Double(cardIndex! - cards.count / 2) * 5)
        let offsetToDiscard = CGSize(
            width: discardPileZone!.midX - cardFrame.midX,
            height: discardPileZone!.midY - cardFrame.midY + yArcOffset
        )
        
        // initial state
        animatingRotation = -180 //card is face down
        animationOffset = .zero
        animationRotationCorrection = fanAngle
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            animatingRotation = 0 //card gets discarded face up
            animationOffset = offsetToDiscard
            animationRotationCorrection = .degrees(0)
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
