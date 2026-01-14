//
//  OpponentHandView.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 1/4/26.
//

import SwiftUI

struct OpponentHandView: View {
    @EnvironmentObject var game: GameManager
    
    //Passed Arguments
    @Binding var cards: [Card]
    let isFaceUp: Bool
    var discardPileZone: CGRect? = nil
    var deckZone: CGRect? = nil
    
    init(cards: [Card], isFaceUp: Bool, discardPileZone: CGRect, deckZone: CGRect) {
        self._cards = .constant(cards)  // Creates a constant binding
        self.isFaceUp = isFaceUp
        self.discardPileZone = discardPileZone
        self.deckZone = deckZone
    }
    
    // For animating from deck/discard
    @State private var slotFrames: [Int: CGRect] = [:]
    @State private var animatingCard: Card?
    @State private var animationOffset: CGSize = .zero
    @State private var animationRotationCorrection: Angle = .zero
    @State private var flipRotation: Double = 0
    @State private var cardWaitingToAnimate: Card?
    
    // Constants
    private let cardWidth: CGFloat = 145 * 0.7
    private let cardHeight: CGFloat = 145
    private let spacing: CGFloat = -67
    private let fanningAngle: Double = 4
    
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(cards) { card in
                let isAnimating = (animatingCard == card)
                let index = cards.firstIndex(of: card)!
                let angle = Angle.degrees(Double(index - cards.count/2) * -fanningAngle)
                //print(isAnimating)
                //print(-abs(Double(index - cards.count / 2) * 5))
                
                CardView(imageName: card.imageName, isFaceUp: isFaceUp, animatableFlipAngle: isAnimating ? flipRotation : 0) //should only be flipping on discard!
                    .zIndex(Double(index))
                    .opacity(cardWaitingToAnimate == card ? 0 : 1)
                    .rotationEffect(isAnimating ? animationRotationCorrection : angle)
                    .offset(y: -abs(Double(index - cards.count / 2) * 5))
                    .offset(isAnimating ? animationOffset : .zero)
                    .shadow(color: game.opponentHasWon ? .yellow : .black.opacity(0.33), radius: isAnimating ? 0 : 20 )
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
            if newHand.count > oldHand.count,
                let drawIndex = game.indexDrawnTo { //the opponent is drawing!
                
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
                height: drawZone.midY - cardFrame.midY + cardHeight/4) //cardHeight/4 is offseting how the deck is built stack is construction and just so happens to match well. will need to change this once the deck starts getting slimmed down
        } else {
            offsetToDraw = CGSize(
                width: drawZone.midX - cardFrame.midX,
                height: drawZone.midY - cardFrame.midY)
        }
        
        if !game.opponentDrewFromDeck {
            flipRotation = -180
        } else { flipRotation = 0 } //likely redundant but lets be safe
        
        // initial state
        animationOffset = offsetToDraw
        animationRotationCorrection = .degrees(0)
        self.cardWaitingToAnimate = nil
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            animationOffset = .zero
            animationRotationCorrection = fanAngle
            flipRotation = 0
        }
            
        // Clear draw animation state and call discard animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            completion()
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
        flipRotation = 0
        animationOffset = .zero
        animationRotationCorrection = fanAngle
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            flipRotation = 180
            animationOffset = offsetToDiscard
            animationRotationCorrection = .degrees(0)
        }
            
        // Resolve animation state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            animatingCard = nil
            animationOffset = .zero
            game.opponentDiscardCard(card: card)
        }
    }
}
