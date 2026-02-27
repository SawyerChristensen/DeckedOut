//
//  Crazy8sGameView.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 2/23/26.
//

import Foundation
import SwiftUI

struct Crazy8sGameView: View {
    @EnvironmentObject var game: Crazy8sManager
    @Environment(\.colorScheme) var colorScheme
    
    @State private var deckFrame: CGRect = .zero
    @State private var discardFrame: CGRect = .zero
    @State private var isHoveringDiscard: Bool = false
    @State private var isDraggedCardPlayable: Bool = false

    
    var body: some View {
        ZStack {
            backgroundView
            
            VStack {
                opponentsHand
                Spacer()
                deckAndDiscard
                Spacer()
                playersHand
                
            }
        }
        .overlay {
            if game.userNeedsToChooseSuit {
                SuitSelectionOverlay()
            }
        }
        
        .overlay {
            if game.phase == .idlePhase {
                WaitingOverlayView()
                    .transition(.opacity.animation(.easeInOut(duration: 0.5)))
            }
            else if game.phase == .gameEndPhase {
                WinScreenView(playerHasWon: game.playerHasWon, gameName: "Out!")
                    .transition(.opacity.animation(.easeInOut(duration: 0.5)))
            }
        }
        .onChange(of: game.turnNumber) { lastTurn, newTurn in
            Task {
                if game.phase == .animationPhase {
                    await animateOpponentsTurn()
                }
            }
        }
        .task { //triggers the first time the view is presented
            if !game.hasPerformedInitialLoad{
                do { try await Task.sleep(nanoseconds: 500_000_000) } catch { }  // 0.5s
            }
            await animateOpponentsTurn()
        }
    }
    
    
    // MARK: - View Sections
    private var backgroundView: some View {
        Image(colorScheme == .dark ? "feltBackgroundDark" : "feltBackgroundLight")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .ignoresSafeArea()
    }
    
    private var opponentsHand: some View {
        Crazy8sOpponentHandView(cards: game.opponentHand, discardPileZone: discardFrame, deckZone: deckFrame)
            .padding(.top, 30)
            .zIndex(2)
    }
    
    private var deckAndDiscard: some View {
        HStack {
            Spacer()
            Spacer()
            Spacer()
            
            theDeck
                .onTapGesture { handleDeckTap() }
            
            Spacer()
            Spacer()
            
            discardPile
            
            Spacer()
            Spacer()
            Spacer()
        }
        .zIndex(1)
    }
    
    private var theDeck: some View {
        ZStack {
            ForEach(0..<5) { i in
                Image("cardBackRed")
                    .resizable()
                    .aspectRatio(0.7, contentMode: .fit)
                    .frame(height: 145)
                    .offset(x: CGFloat(-i) * 3, y: CGFloat(-i) * 3)
                    .shadow(radius: i == 4 ? 1 : 8)
                    .background {
                        if i == 4 { // 4 is top card, the stack proceeds up-left, not down-right
                            GeometryReader { geo in
                                Color.clear
                                    .onAppear {
                                        deckFrame = calculateProperDeckZone(from: geo.frame(in: .global))
                                    }
                                    .onChange(of: geo.frame(in: .global)) { _, newFrame in
                                        deckFrame = calculateProperDeckZone(from: newFrame)
                                    }
                            }
                        }
                    }
            }
        }
    }
    
    private func handleDeckTap() {
        if game.phase == .mainPhase && !game.userCanDiscard {
            game.drawFromDeck()
            SoundManager.instance.playCardDeal()
        } else {
            SoundManager.instance.playErrorFeedback()
        }
    }
    
    private var discardPile: some View { //Clear background probably not needed, but its guarantees safety. (open to review)
        ZStack {
            Color.clear // A ghost view reserves the space so Spacers don't collapse when discardPile.count == 0
                .frame(width: 101.5, height: 145) // 101.5 = 145 * 0.7
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { discardFrame = geo.frame(in: .global) }
                            .onChange(of: geo.frame(in: .global)) { _, newFrame in
                                discardFrame = newFrame
                            }
                    }
                )
            
            if let activeSuit = game.activeSuitOverride { //selected suit reminder text
                Text("Selected:\n\(Image(systemName: activeSuit.sfSymbolName)) \(activeSuit.localizedName)")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    //.padding(.horizontal, 10)
                    //.padding(.vertical, 6)
                    //.background(Capsule().fill(.black.opacity(0.6)))
                    .offset(y: -100) //7.5 pizels above the discard
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            if let topCard = game.discardPile.last { // we have cards in the discard pile; display the top one
                CardView(frontImage: topCard.imageName)
                    .shadow(color: isDraggedCardPlayable && isHoveringDiscard ? .white : .black.opacity(0.2),
                            radius: isDraggedCardPlayable && isHoveringDiscard ? 15 : 5)
                    .scaleEffect(isDraggedCardPlayable && isHoveringDiscard ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isHoveringDiscard)
            }
        }
    }
    
    private var playersHand: some View {
        Crazy8sPlayerHandView(
            cards: $game.playerHand,
            discardPileZone: discardFrame,
            deckZone: deckFrame,
            onDragChanged: { card, location in
                handleDragChanged(card: card, location: location)
            },
            onDragEnded: { card, location in
                handleDragEnded(card: card, location: location)
            }
        )
        .padding(.bottom, 40)
        .shadow(color: game.playerHasWon ? .yellow : .black.opacity(0.25), radius: game.playerHasWon ? 15 : 5, x: game.playerHasWon ? 5 : 0)
        .zIndex(1)
    }
    
    
    // MARK: - Helper functions
    private func animateOpponentsTurn() async { //modifies backend, which triggers animation in opponentHandView
        if game.cardsOpponentDrew > 0 {
            for _ in 0..<game.cardsOpponentDrew {
                game.opponentDrawFromDeck()
                
                do { // Wait for the draw animation to finish before drawing the next one
                    try await Task.sleep(nanoseconds: 800_000_000) // 0.8s
                } catch { }
            }
        }
        
        if let cardToDiscard = game.opponentCardPendingDiscard {
            game.opponentCardAnimatingToDiscard = cardToDiscard
            
            do {
                try await Task.sleep(nanoseconds: 600_000_000) // 0.6s for discard animation
            } catch { }
        }
        
        game.hasPerformedInitialLoad = true
        //animating discard is automatically handled in opponents hand view
    }
    
    private func calculateProperDeckZone(from frame: CGRect) -> CGRect {
        var newFrame = frame
        let topIndex = 4
        let offsetPerCard: CGFloat = -2
        
        let totalOffset = CGFloat(topIndex) * offsetPerCard
        
        newFrame.origin.x += totalOffset
        newFrame.origin.y += totalOffset * 4.5
        
        return newFrame
    }
    
    private func handleDragChanged(card: Card, location: CGPoint) {
        let isNowHovering = discardFrame.contains(location)
        
        if isNowHovering != isHoveringDiscard { //a card has entered/exited the zone. calculate UI updates once instead of continuously
            isHoveringDiscard = isNowHovering
            
            if isNowHovering { //the card just entered the discard zone. check if playable
                isDraggedCardPlayable = game.isCardPlayable(card)
            } else {
                isDraggedCardPlayable = false
            }
        }
    }

    private func handleDragEnded(card: Card, location: CGPoint) {
        if discardFrame.contains(location) {
            if game.phase == .mainPhase { //redudant, we check this twice, but it might be a split second faster
                game.discardCard(card: card)
            } else {
                print(game.phase)
                SoundManager.instance.playErrorFeedback()
            }
        } else {
            //print("Drop → No zone, card returns")
        }
        isHoveringDiscard = false
        
    }
    
}
