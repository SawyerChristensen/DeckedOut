//
//  GolfGameView.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 4/15/26.
//

import Foundation
import SwiftUI

struct GolfGameView: View {
    @EnvironmentObject var game: GolfManager
    @Environment(\.colorScheme) var colorScheme
    
    @State private var deckFrame: CGRect = .zero
    @State private var discardFrame: CGRect = .zero
    @State private var lastDrawSource: DrawSource = .none
    @State private var isHoveringDiscard: Bool = false
    @State private var showRules: Bool = false
    @ScaledMetric(relativeTo: .title) private var scaledButtonUnit: CGFloat = 10
    private var buttonSize: CGFloat { scaledButtonUnit * 4 }

    
    var body: some View {
        ZStack {
            backgroundView
            
            VStack {
                //opponentsHand
                playersHand
                    .rotationEffect(.degrees(180))
                    .padding(.top, 15)
                Spacer()
                    .frame(maxWidth: UIScreen.main.bounds.width)
                deckAndDiscard
                //rulesButtonSection
                Spacer()
                    .frame(maxWidth: UIScreen.main.bounds.width)
                playersHand
                    .padding(.bottom, 20)
                
            }
        }
        .overlay {
            if game.phase == .idlePhase {
                WaitingOverlayView()
                    .transition(.opacity.animation(.easeInOut(duration: 0.5)))
            }
            else if game.phase == .gameEndPhase {
                WinScreenView(playerHasWon: game.playerHasWon, winMessage: "Golf")
                    .transition(.opacity.animation(.easeInOut(duration: 0.5)))
            }
            
            if showRules {
                RulesView(gameType: .golf, isExpanded: true, onDismiss: { showRules = false })
                    .frame(maxWidth: UIScreen.main.bounds.width)
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            }
        }
        .onChange(of: game.turnNumber) { lastTurn, newTurn in
            if game.phase == .animationPhase {
                animateOpponentsTurn()
            }
        }
        .task { //triggers the first time the view is presented
            if !game.hasPerformedInitialLoad{
                do {
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                } catch { }
            }
            animateOpponentsTurn()
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
        GolfOpponentHandView(cards: game.opponentHand, discardPileZone: discardFrame, deckZone: deckFrame)
            //.padding(.top, 30)
            .zIndex(2)
    }
    
    private var deckAndDiscard: some View {
        HStack {
            Spacer()
            Spacer()
            theDeck
                .onTapGesture { handleDeckTap() }

            rulesButtonSection
                .padding(.horizontal)
            
            discardPile
            Spacer()
            //rulesButtonSection
                //.padding(.horizontal)
            Spacer()
            //Spacer()
        }
        .zIndex(1)
    }
    
    private var theDeck: some View {
        ZStack {
            ForEach(0..<5) { i in
                Image("cardBackRed")
                    .resizable()
                    .aspectRatio(0.7, contentMode: .fit)
                    .frame(height: 130)
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
        if game.phase == .drawPhase {
            game.drawFromDeck()
            lastDrawSource = .deck
            SoundManager.instance.playCardDeal()
        } else {
            SoundManager.instance.playErrorFeedback()
        }
    }
    
    private var discardPile: some View {
        ZStack {
            Color.clear // A ghost view reserves the space so Spacers don't collapse when discardPile.count == 0
                .frame(width: 91, height: 130) // 91 = 130 * 0.7
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { discardFrame = geo.frame(in: .global) }
                            .onChange(of: geo.frame(in: .global)) { _, newFrame in
                                discardFrame = newFrame
                            }
                    }
                )
            
            if let topCard = game.discardPile.last { // we have cards in the discard pile; display the top one
                CardView(frontImage: topCard.imageName)
                    .aspectRatio(0.7, contentMode: .fit)
                    .frame(width: 91, height: 130)
                    .onTapGesture { handleDiscardTap() }
            } else { // display an outline of where a discarded card *should* go
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 2)
                    .frame(width: 91, height: 130)
            }
        }
    }
    
    private func handleDiscardTap() {
        if game.phase == .drawPhase {
            game.drawFromDiscard()
            lastDrawSource = .discard
            SoundManager.instance.playCardDeal()
        } else {
            SoundManager.instance.playErrorFeedback()
        }
    }
    
    private var rulesButtonSection: some View {
        ZStack(alignment: .bottom) {
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                withAnimation(.easeInOut(duration: 0.2)) {
                    showRules = true
                }
            }) {
                Image(systemName: "text.book.closed")
                    .resizable()
                    .scaledToFit()
                    .frame(width: buttonSize, height: buttonSize)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.top, 60)
        }
        .frame(height: 130)
    }
    
    private var playersHand: some View {
        GolfPlayerHandView(
            cards: $game.playerHand,
            discardPileZone: discardFrame,
            deckZone: deckFrame,
            lastDrawSource: lastDrawSource,
            onDragChanged: { card, location in
                handleDragChanged(card: card, location: location)
            },
            onDragEnded: { card, location in
                handleDragEnded(card: card, location: location)
            }
        )
        //.padding(.bottom, 40)
        .shadow(color: game.playerHasWon ? .yellow : .black.opacity(0.25), radius: game.playerHasWon ? 15 : 5, x: game.playerHasWon ? 5 : 0)
        .zIndex(1)
    }
    
    
    // MARK: - Helper functions
    private func animateOpponentsTurn() { //modifies backend, which triggers animation in opponentHandView
        game.opponentReplaceCard()
        game.hasPerformedInitialLoad = true
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
        /*if discardFrame.contains(location) {
            isHoveringDiscard = true
        } else {
            isHoveringDiscard = false
        }*/
    }

    private func handleDragEnded(card: Card, location: CGPoint) { //change to handle a drag from the deck or discard to a specific zone in the players hand
        if discardFrame.contains(location) {
            if game.phase == .placementPhase,
               let index = game.playerHand.firstIndex(of: card) {
                game.replaceCard(at: index)
            } else {
                SoundManager.instance.playErrorFeedback()
            }
        } else {
            //print("Drop → No zone, card returns")
        }
    }
    
}
