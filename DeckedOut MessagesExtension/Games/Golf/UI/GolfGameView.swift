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
    @State private var playerSlotFrames: [Int: CGRect] = [:]
    @State private var isDraggingFromSource: Bool = false
    @State private var dragLocation: CGPoint = .zero
    @State private var hoveringCardOffset: CGSize = .zero
    @State private var wobblePhase: Bool = false
    @State private var departingIndex: Int? = nil
    @State private var departingOffset: CGSize = .zero
    @State private var isAnimatingPlacement: Bool = false
    @State private var overlayCenter: CGPoint = .zero
    @State private var hoveringFlipRotation: Double = 0
    @ScaledMetric(relativeTo: .title) private var scaledButtonUnit: CGFloat = 10
    private var buttonSize: CGFloat { scaledButtonUnit * 4 }

    
    var body: some View {
        ZStack {
            backgroundView
            
            VStack {
                //opponentsHand
                opponentDisplayHand
                    .rotationEffect(.degrees(180))
                    .padding(.top, 15)
                Spacer()
                    .frame(maxWidth: UIScreen.main.bounds.width)
                deckAndDiscard
                //rulesButtonSection
                Spacer()
                    .frame(maxWidth: UIScreen.main.bounds.width)
                interactivePlayerHand
                    .padding(.bottom, 20)

            }

            // Hovering card overlay
            hoveringCardOverlay
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        let frame = geo.frame(in: .global)
                        overlayCenter = CGPoint(x: frame.midX, y: frame.midY)
                    }
                    .onChange(of: geo.frame(in: .global)) { _, newFrame in
                        overlayCenter = CGPoint(x: newFrame.midX, y: newFrame.midY)
                    }
            }
        )
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
                .gesture(
                    DragGesture(minimumDistance: 10, coordinateSpace: .global)
                        .onChanged { value in
                            handleSourceDrag(source: .deck, location: value.location)
                        }
                        .onEnded { value in
                            handleSourceDragEnd(at: value.location)
                        }
                )
            
            Spacer()

            rulesButtonSection
                .padding(.horizontal)
            
            Spacer()

            discardPile
                .gesture(
                    DragGesture(minimumDistance: 10, coordinateSpace: .global)
                        .onChanged { value in
                            handleSourceDrag(source: .discard, location: value.location)
                        }
                        .onEnded { value in
                            handleSourceDragEnd(at: value.location)
                        }
                )
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
            // Start offset at deck position, compensating for the -75 hover float
            hoveringCardOffset = CGSize(
                width: deckFrame.midX - overlayCenter.x,
                height: deckFrame.midY - overlayCenter.y + 75
            )
            hoveringFlipRotation = -180
            game.drawFromDeck()
            lastDrawSource = .deck
            SoundManager.instance.playCardDeal()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                hoveringCardOffset = .zero
                hoveringFlipRotation = 0
            }
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
            hoveringCardOffset = CGSize(
                width: discardFrame.midX - overlayCenter.x,
                height: discardFrame.midY - overlayCenter.y + 75
            )
            hoveringFlipRotation = 0
            game.drawFromDiscard()
            lastDrawSource = .discard
            SoundManager.instance.playCardDeal()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                hoveringCardOffset = .zero
            }
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
            .padding(.top, 55)
        }
        .frame(height: 130)
    }
    
    private var isHovering: Bool {
        !isDraggingFromSource && !isAnimatingPlacement
    }

    @ViewBuilder
    private var hoveringCardOverlay: some View {
        if let hoveringCard = game.hoveringCard {
            CardView(frontImage: hoveringCard.imageName, rotation: hoveringFlipRotation)
                .frame(width: 91, height: 130)
                .shadow(color: .black.opacity(0.5), radius: 20)
                .scaleEffect(isHovering ? 1.1 : 1.0)
                .rotationEffect(.degrees(isHovering ? (wobblePhase ? 2 : -2) : 0))
                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: wobblePhase)
                .offset(
                    isDraggingFromSource
                        ? CGSize(width: dragLocation.x - overlayCenter.x, height: dragLocation.y - overlayCenter.y)
                        : CGSize(width: hoveringCardOffset.width, height: hoveringCardOffset.height + (isHovering ? -75 : 0))
                )
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isAnimatingPlacement)
                .zIndex(50)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
                .onAppear {
                    wobblePhase = true
                }
                .onDisappear {
                    wobblePhase = false
                }
        }
    }

    private var opponentDisplayHand: some View {
        GolfPlayerHandView(
            cards: game.opponentHand,
            discardPileZone: discardFrame,
            deckZone: deckFrame,
            lastDrawSource: .none
        )
        .shadow(color: game.playerHasWon ? .yellow : .black.opacity(0.25), radius: game.playerHasWon ? 15 : 5, x: game.playerHasWon ? 5 : 0)
        .zIndex(1)
    }

    private var interactivePlayerHand: some View {
        GolfPlayerHandView(
            cards: $game.playerHand,
            discardPileZone: discardFrame,
            deckZone: deckFrame,
            lastDrawSource: lastDrawSource,
            departingIndex: departingIndex,
            departingOffset: departingOffset,
            onDragChanged: { card, location in
                handleDragChanged(card: card, location: location)
            },
            onDragEnded: { card, location in
                handleDragEnded(card: card, location: location)
            },
            onCardTapped: { index in
                handleCardTapped(at: index)
            },
            onSlotFrameChanged: { index, frame in
                playerSlotFrames[index] = frame
            }
        )
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
        // The top card (i=4) is visually offset by (-12, -12) via .offset(x: -i*3, y: -i*3)
        // but .offset doesn't change the layout frame, so we correct manually
        let visualOffset: CGFloat = -12
        newFrame.origin.x += visualOffset
        newFrame.origin.y += visualOffset
        return newFrame
    }
 
    private func handleDragChanged(card: Card, location: CGPoint) {
        /*if discardFrame.contains(location) {
            isHoveringDiscard = true
        } else {
            isHoveringDiscard = false
        }*/
    }

    private func handleDragEnded(card: Card, location: CGPoint) {
        if discardFrame.contains(location) {
            if game.phase == .placementPhase,
               let index = game.playerHand.firstIndex(of: card) {
                animatePlacement(at: index)
            } else {
                SoundManager.instance.playErrorFeedback()
            }
        }
    }

    private func handleCardTapped(at index: Int) {
        if game.phase == .placementPhase {
            animatePlacement(at: index)
        } else {
            SoundManager.instance.playErrorFeedback()
        }
    }

    private func animatePlacement(at index: Int) {
        guard !isAnimatingPlacement else { return }
        isAnimatingPlacement = true

        // Animate hovering card toward the target slot
        if let slotFrame = playerSlotFrames[index] {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                hoveringCardOffset = CGSize(
                    width: slotFrame.midX - overlayCenter.x,
                    height: slotFrame.midY - overlayCenter.y
                )
            }
        }

        // Animate the tapped card toward the discard pile
        departingIndex = index
        if let slotFrame = playerSlotFrames[index] {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                departingOffset = CGSize(
                    width: discardFrame.midX - slotFrame.midX,
                    height: discardFrame.midY - slotFrame.midY
                )
            }
        }

        // Commit the swap after animations land
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            game.replaceCard(at: index)
            departingIndex = nil
            departingOffset = .zero
            hoveringCardOffset = .zero
            hoveringFlipRotation = 0
            isAnimatingPlacement = false
        }
    }

    private func handleSourceDrag(source: DrawSource, location: CGPoint) {
        if !isDraggingFromSource && game.phase == .drawPhase {
            // First drag movement — draw the card
            if source == .deck {
                hoveringFlipRotation = -180
                game.drawFromDeck()
                lastDrawSource = .deck
                withAnimation(.easeOut(duration: 0.3)) {
                    hoveringFlipRotation = 0
                }
            } else {
                hoveringFlipRotation = 0
                game.drawFromDiscard()
                lastDrawSource = .discard
            }
            isDraggingFromSource = true
            SoundManager.instance.playCardDeal()
        }
        dragLocation = location
    }

    private func handleSourceDragEnd(at location: CGPoint) {
        guard isDraggingFromSource else { return }

        // Transfer drag position into hoveringCardOffset before switching modes
        hoveringCardOffset = CGSize(
            width: location.x - overlayCenter.x,
            height: location.y - overlayCenter.y
        )
        isDraggingFromSource = false

        // Check if dropped on a player hand slot
        for (index, frame) in playerSlotFrames {
            if frame.contains(location) {
                animatePlacement(at: index)
                return
            }
        }

        // Not dropped on a slot — snap to center as hovering card
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            hoveringCardOffset = .zero
        }
    }

}
