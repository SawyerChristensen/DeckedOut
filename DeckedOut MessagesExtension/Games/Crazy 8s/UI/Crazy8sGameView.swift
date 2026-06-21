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
    @Environment(\.accessibilityShowButtonShapes) private var showButtonShapes
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motionSpeed: Double { reduceMotion ? 0.66 : 1.0 } //animations should run at 2/3 speed when "Reduce Motion" is enabled
    @ObservedObject private var cardBackSelection = DeckThemeSelection.shared

    @State private var deckFrame: CGRect = .zero
    @State private var discardFrame: CGRect = .zero
    @State private var isHoveringDiscard: Bool = false
    @State private var isDraggedCardPlayable: Bool = false
    @State private var showRules: Bool = false
    @State private var cardSortState: Int = 0 // 0 = original order, 1 = sorted by suit then rank, 2 = sorted by rank
    @ScaledMetric(relativeTo: .largeTitle) var rulesButtonSize: CGFloat = 36
    @ScaledMetric(relativeTo: .title) var suitTextOffset: CGFloat = -100
    
    var body: some View {
        ZStack {
            VStack {
                opponentsHand
                Spacer()
                    .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? game.extensionWidth : UIScreen.main.bounds.width)
                deckAndDiscard
                rulesButtonSection
                playersHand

            }
        }
        .background(FeltBackgroundView(inGame: true))
        .overlay {
            if game.userNeedsToChooseSuit {
                SuitSelectionOverlay()
            }
        }
        .overlay {
            if game.phase == .idlePhase {
                WaitingOverlayView(
                    joinedCount: game.isJoiningPhase ? game.seats.filter { $0 != Crazy8sManager.unclaimedSeat }.count : nil,
                    totalCount: game.isJoiningPhase ? game.seats.count : nil
                )
                    .transition(.opacity.animation(.easeInOut(duration: 0.5).speed(motionSpeed)))
            }
            else if game.phase == .gameEndPhase {
                WinScreenView(playerHasWon: game.playerHasWon, winMessage: String(localized: "Out!", comment: "Win screen message for Crazy 8s"))
                    .transition(.opacity.animation(.easeInOut(duration: 0.5).speed(motionSpeed)))
            }
        }
        .accessibilityHidden(showRules)
        .overlay {
            if showRules {
                RulesView(gameType: .crazy8s, isExpanded: true, onDismiss: { showRules = false })
                    .frame(maxWidth: UIScreen.main.bounds.width)
                    .transition(.opacity.animation(.easeInOut(duration: 0.2).speed(motionSpeed)))
            }
        }
        .onChange(of: game.turnNumber) { lastTurn, newTurn in
            Task {
                if game.phase == .animationPhase || game.isAnimatingOpponentTurn {
                    await animateOpponentsTurn()
                }
            }
        }
        .task { //triggers the first time the view is presented
            if !game.hasPerformedInitialLoad, hasOpponentVisualsToAnimate {
                do { try await Task.sleep(nanoseconds: 500_000_000) } catch { }  // 0.5s
            }
            await animateOpponentsTurn()
        }
    }
    
    
    // MARK: - View Sections
    private var opponentsHand: some View {
        Crazy8sOpponentsArcView(discardPileZone: discardFrame, deckZone: deckFrame)
            .padding(.top, 30)
            .zIndex(2)
    }
    
    private var deckAndDiscard: some View {
        HStack {
            Spacer()
            Spacer()
            Spacer()
            
            theDeck

            Spacer()
            Spacer()
            
            discardPile
            
            Spacer()
            Spacer()
            Spacer()
        }
        .zIndex(1)
    }
    
    private var isMyTurn: Bool {
        game.phase == .mainPhase
    }

    private var showsPlayerDeckBack: Bool {
        isMyTurn || game.deckShouldShowPlayerBack
    }

    private var theDeck: some View {
        ZStack {
            ForEach(0..<5) { i in
                ZStack {
                    Image(cardBackSelection.selectedName)
                        .resizable()
                        .aspectRatio(0.7, contentMode: .fit)
                        .opacity(showsPlayerDeckBack ? 1 : 0)
                    Image(game.opponentDeckCardBack)
                        .resizable()
                        .aspectRatio(0.7, contentMode: .fit)
                        .opacity(showsPlayerDeckBack ? 0 : 1)
                }
                .frame(height: 145)
                .offset(x: CGFloat(-i) * 3, y: CGFloat(-i) * 3)
                .shadow(radius: i == 4 ? 1 : 8)
                .animation(cardBackSelection.selectedName == game.opponentDeckCardBack ? nil : .easeInOut(duration: 0.4).speed(motionSpeed), value: showsPlayerDeckBack)
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
        .onTapGesture { handleDeckTap() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Deck", comment: "Voice Control label for drawing a card from the deck"))
        .accessibilityHint(Text("Draws a card into your hand.", comment: "Context for VoiceOver users"))
        .accessibilityInputLabels([
            Text("Deck", comment: "Voice Control input label"),
            Text("the deck", comment: "Voice Control input label"),
            Text("Draw from the deck", comment: "Voice Control input label"),
            Text("Draw from deck", comment: "Voice Control input label")
        ])
        .accessibilityAddTraits([.isImage, .isButton])
        .accessibilityAction { handleDeckTap() }
    }
    
    private func handleDeckTap() {
        if game.phase == .mainPhase && !game.userCanDiscard {
            game.drawFromDeck()
            SoundManager.instance.playCardDeal()
        } else {
            HapticManager.instance.playErrorFeedback()
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
                    .offset(y: suitTextOffset) //7.5 pixels above the discard
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            if let topCard = game.discardPile.last { // we have cards in the discard pile; display the top one
                CardView(frontImage: topCard.imageName)
                    .shadow(color: isDraggedCardPlayable && isHoveringDiscard ? .white : .black.opacity(0.2),
                            radius: isDraggedCardPlayable && isHoveringDiscard ? 15 : 5)
                    .scaleEffect(isDraggedCardPlayable && isHoveringDiscard ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.2).speed(motionSpeed), value: isHoveringDiscard)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(discardPileAccessibilityLabel))
        .accessibilityAddTraits(.isImage)
    }

    private var discardPileAccessibilityLabel: String {
        guard let topCard = game.discardPile.last else {
            return String(localized: "Empty discard pile.", comment: "VoiceOver label when the discard pile has no cards")
        }
        let topCardDescription = String(
            format: String(localized: "Top card: %@ of %@.", comment: "VoiceOver label for the top card of the discard pile, e.g. Top card: Queen of Hearts."),
            topCard.rank.localizedName,
            topCard.suit.localizedName
        )
        if let activeSuit = game.activeSuitOverride {
            let activeSuitDescription = String(
                format: String(localized: "Active suit: %@.", comment: "VoiceOver label for the suit chosen after an 8 was played"),
                activeSuit.localizedName
            )
            return "\(topCardDescription) \(activeSuitDescription)"
        }
        return topCardDescription
    }

    private var rulesButtonSection: some View {
        Spacer()
            .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? game.extensionWidth : UIScreen.main.bounds.width)
            .overlay(
                HStack(spacing: rulesButtonSize / 2) {
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        withAnimation(.easeInOut(duration: 0.2).speed(motionSpeed)) {
                            showRules = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "text.book.closed")
                                .font(.system(size: rulesButtonSize))

                            if showButtonShapes {
                                Text("Rules")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                        }
                        .foregroundStyle(.white.opacity(showButtonShapes ? 1.0 : 0.5))
                        .padding(showButtonShapes ? EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16) : EdgeInsets())
                        .background(
                            Group {
                                if showButtonShapes {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                }
                            }
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Rules", comment: "Voice Control label for opening the rules"))
                    .accessibilityInputLabels([
                        Text("Rules", comment: "Voice Control input label"),
                        Text("the rules", comment: "Voice Control input label"),
                        Text("Game rules", comment: "Voice Control input label"),
                        Text("Show rules", comment: "Voice Control input label"),
                        Text("Show game rules", comment: "Voice Control input label")
                    ])
                    
                    sortButton
                    
                    Spacer()
                }
                .padding(.top, 10)
                .padding(.horizontal, 30)
            )
    }
    
    private var sortButton: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            withAnimation(.spring(response: 0.5, dampingFraction: 1)) {
                cardSortState = (cardSortState + 1) % 3
                game.sortPlayerHand(sortState: cardSortState)
            }
        }) {
            HStack {
                Image(systemName: cardSortState == 0 ? "arrow.left.arrow.right" : (cardSortState == 1 ? "arrow.up.right" : "arrow.right"))
                    .font(.system(size: rulesButtonSize))
                    .contentTransition(.symbolEffect(.replace))

                if showButtonShapes {
                    Text(cardSortState == 0 ? "Sort" : (cardSortState == 1 ? "Suit/Rank" : "Rank"))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .foregroundStyle(.white.opacity(showButtonShapes ? 1.0 : 0.5))
            .padding(showButtonShapes ? EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16) : EdgeInsets())
            .background(
                Group {
                    if showButtonShapes {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Sort hand", comment: "Voice Control label for sorting the player's hand"))
        .accessibilityHint(Text("Cycles between the original order, sorted by suit and rank, and sorted by rank.", comment: "VoiceOver hint for the sort button"))
        .accessibilityInputLabels([
            Text("Sort", comment: "Voice Control input label"),
            Text("Sort hand", comment: "Voice Control input label"),
            Text("Sort cards", comment: "Voice Control input label")
        ])
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
        .shadow(color: .black.opacity(0.25), radius: 5) //no yellow glow because if the player has won, they have no more cards in hand!
        .zIndex(1)
    }
    
    
    private var hasOpponentVisualsToAnimate: Bool {
        game.cardsOpponentDrew > 0
            || !game.opponentQueensPendingDiscard.isEmpty
            || game.opponentCardPendingDiscard != nil
            || game.pendingPlayerPenaltyDraws > 0
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

        //V1 1v1: animate any queens the opponent played before their final card (queens grant another turn).
        if !game.opponentQueensPendingDiscard.isEmpty {
            for queen in game.opponentQueensPendingDiscard {
                game.opponentCardAnimatingToDiscard = queen
                do {
                    try await Task.sleep(nanoseconds: 600_000_000) // 0.6s for discard animation
                } catch { }
            }
            game.opponentQueensPendingDiscard = []
        }

        if let cardToDiscard = game.opponentCardPendingDiscard {
            game.opponentCardAnimatingToDiscard = cardToDiscard

            do {
                try await Task.sleep(nanoseconds: 600_000_000) // 0.6s for discard animation
            } catch { }
        }

        // Penalty draws (e.g. opponent played a 2): animate cards from deck into the local player's hand
        if game.pendingPlayerPenaltyDraws > 0 {
            // Cross-fade the deck to the user's card back before the penalty cards animate out, so the card and deck share a back.
            game.deckShouldShowPlayerBack = true
            do {
                try await Task.sleep(nanoseconds: 400_000_000) // 0.4s, matches the deck cross-fade duration
            } catch { }

            let count = game.pendingPlayerPenaltyDraws
            for _ in 0..<count {
                game.userDrawPenaltyCard()
                do {
                    try await Task.sleep(nanoseconds: 800_000_000) // 0.8s
                } catch { }
            }

            if game.isAnimatingOpponentTurn {
                game.isAnimatingOpponentTurn = false
            } else if game.phase == .animationPhase {
                game.phase = .mainPhase
                game.checkHandPlayability()
            }
            //clear the override so the next phase change (e.g. user playing a 2) flips the deck to the opponent's back
            game.deckShouldShowPlayerBack = false
        } else if game.opponentCardPendingDiscard == nil {
            if game.isAnimatingOpponentTurn {
                game.isAnimatingOpponentTurn = false
            } else if game.phase == .animationPhase {
                game.phase = .mainPhase
                game.checkHandPlayability()
            }
        }

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
                HapticManager.instance.playErrorFeedback()
            }
        } else {
            //print("Drop → No zone, card returns")
        }
        isHoveringDiscard = false
        
    }
    
}
