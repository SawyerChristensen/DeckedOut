//
//  GinGameView.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 11/17/25.
//

import Foundation
import SwiftUI

struct GinGameView: View {
    @EnvironmentObject var game: GinRummyManager
    //@Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.accessibilityShowButtonShapes) private var showButtonShapes
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motionSpeed: Double { reduceMotion ? 0.66 : 1.0 } //animations should run at 2/3 speed when "Reduce Motion" is enabled
    @ObservedObject private var cardBackSelection = CardBackSelection.shared

    @State private var deckFrame: CGRect = .zero
    @State private var discardFrame: CGRect = .zero
    @State private var lastDrawSource: DrawSource = .none
    @State private var isHoveringDiscard: Bool = false
    @State private var showRules: Bool = false
    @State private var handShadowRadius: CGFloat = 5
    @State private var cardSortState: Int = 0 // 0 = unsorted, 1 = sorted ascending, 2 = sorted descending
    @ScaledMetric(relativeTo: .largeTitle) var rulesButtonSize: CGFloat = 36
    
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
            if game.phase == .idlePhase {
                WaitingOverlayView(
                    joinedCount: game.isJoiningPhase ? game.seats.filter { $0 != GinRummyManager.unclaimedSeat }.count : nil,
                    totalCount: game.isJoiningPhase ? game.seats.count : nil
                )
                    .transition(.opacity.animation(.easeInOut(duration: 0.5).speed(motionSpeed)))
            }
            else if game.phase == .gameEndPhase {
                WinScreenView(playerHasWon: game.playerHasWon, winMessage: String(localized: "Gin Rummy!", comment: "Win screen message for Gin Rummy"))
                    .transition(.opacity.animation(.easeInOut(duration: 0.5).speed(motionSpeed)))
            }
        }
        .accessibilityHidden(showRules)
        .overlay {
            if showRules {
                RulesView(
                    gameType: .ginRummy,
                    showsGinKnockRules: game.shouldShowKnockRules,
                    isExpanded: true,
                    onDismiss: { showRules = false }
                )
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
            if !game.hasPerformedInitialLoad {
                do { try await Task.sleep(nanoseconds: 500_000_000) } catch { } // 0.5s
            }
            await animateOpponentsTurn()
        }
    }
    
    
    // MARK: - View Sections
    private var opponentsHand: some View {
        GinOpponentsArcView(discardPileZone: discardFrame, deckZone: deckFrame)
            .padding(.top, 25)
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
        game.phase == .drawPhase || game.phase == .discardPhase
    }

    private var theDeck: some View {
        ZStack {
            ForEach(0..<5) { i in
                ZStack {
                    Image(cardBackSelection.selectedName)
                        .resizable()
                        .aspectRatio(0.7, contentMode: .fit)
                        .opacity(isMyTurn ? 1 : 0)
                    Image(game.opponentDeckCardBack)
                        .resizable()
                        .aspectRatio(0.7, contentMode: .fit)
                        .opacity(isMyTurn ? 0 : 1)
                }
                .frame(height: 145)
                .offset(x: CGFloat(-i) * 3, y: CGFloat(-i) * 3)
                .shadow(radius: i == 4 ? 1 : 8)
                .animation(cardBackSelection.selectedName == game.opponentDeckCardBack ? nil : .easeInOut(duration: 0.4).speed(motionSpeed), value: isMyTurn)
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
        if game.phase == .drawPhase {
            game.drawFromDeck()
            lastDrawSource = .deck
            SoundManager.instance.playCardDeal()
        } else {
            HapticManager.instance.playErrorFeedback()
        }
    }
    
    private var discardPile: some View {
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
            
            if let topCard = game.discardPile.last { // we have cards in the discard pile; display the top one
                CardView(frontImage: topCard.imageName)
                    //.id(topCard.id) //for instant transitions
                    //.transition(.identity) // /to get rid of fade
                    .onTapGesture { handleDiscardTap() }
                    .shadow(color: game.phase == .discardPhase && isHoveringDiscard ? .white : .black.opacity(0.2),
                            radius: game.phase == .discardPhase && isHoveringDiscard ? 15 : 5)
                    .scaleEffect(game.phase == .discardPhase && isHoveringDiscard ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.2).speed(motionSpeed), value: isHoveringDiscard)
            } else { // display an outline of where a discarded card *should* go
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 2)
                    .frame(width: 101.5, height: 145)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Discard pile", comment: "Voice Control label for drawing a card from the discard pile"))
        .accessibilityInputLabels([
            Text("Discard pile", comment: "Voice Control input label"),
            Text("the discard pile", comment: "Voice Control input label"),
            Text("Draw from the discard pile", comment: "Voice Control input label"),
            Text("Draw from discard pile", comment: "Voice Control input label")
        ])
        .accessibilityAddTraits([.isImage, .isButton])
        .accessibilityAction { handleDiscardTap() }
    }
    
    private func handleDiscardTap() {
        if game.phase == .drawPhase {
            game.drawFromDiscard()
            lastDrawSource = .discard
            SoundManager.instance.playCardDeal()
        } else {
            HapticManager.instance.playErrorFeedback()
        }
    }
    
    private var rulesButtonSection: some View {
        Spacer()
            .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? game.extensionWidth : UIScreen.main.bounds.width)
            .overlay(
                HStack {
                    if game.canPlayerKnock {
                        // The player declares knock before discarding; the discard action resolves the round.
                        Button(action: {
                            game.requestKnock()
                        }) {
                            HStack {
                                Image(systemName: game.isKnockArmed ? "hand.raised.fill" : "hand.raised")
                                    .font(.system(size: rulesButtonSize * 0.82))

                                if game.isKnockArmed {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: rulesButtonSize * 0.55))
                                }

                                if showButtonShapes {
                                    Text("Knock")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                }
                            }
                            .foregroundStyle(game.isKnockArmed ? Color.white : Color.white.opacity(0.95))
                            .padding(showButtonShapes ? EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16) : EdgeInsets())
                            .background(
                                Group {
                                    if showButtonShapes {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(game.isKnockArmed ? Color.green.opacity(0.35) : .ultraThinMaterial)
                                    }
                                }
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Knock", comment: "VoiceOver accessibility label for the knock button in Gin Rummy"))
                        .accessibilityHint(Text(game.isKnockArmed ? "Knock is activated. Discard a card to knock." : "Declare a knock, then discard to end the round.", comment: "VoiceOver hint for the knock button in Gin Rummy"))
                        .accessibilityInputLabels([
                            Text("Knock", comment: "Voice Control input label for the knock button in Gin Rummy"),
                            Text("Declare knock", comment: "Voice Control input label for declaring a knock in Gin Rummy"),
                            Text("Call knock", comment: "Voice Control input label for declaring a knock in Gin Rummy")
                        ])
                    }

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

                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        cardSortState = (cardSortState + 1) % 3
                        game.sortPlayerHand(sortState: cardSortState)
                    }) {
                        HStack {
                            Image(systemName: cardSortState == 0 ? "arrow.up.arrow.down" : (cardSortState == 1 ? "arrow.up" : "arrow.down"))
                                .font(.system(size: rulesButtonSize))

                            if showButtonShapes {
                                Text(cardSortState == 0 ? "Sort" : (cardSortState == 1 ? "Asc" : "Desc"))
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
                    .accessibilityLabel(Text("Sort hand", comment: "Voice Control label for sorting the player's hand"))
                    .accessibilityHint(Text("Cycles between unsorted, ascending, and descending sort.", comment: "VoiceOver hint for the sort button"))
                    .accessibilityInputLabels([
                        Text("Sort", comment: "Voice Control input label"),
                        Text("Sort hand", comment: "Voice Control input label"),
                        Text("Sort cards", comment: "Voice Control input label")
                    ])
                    
                    Spacer()
                }
                .padding(.top, 10)
                .padding(.horizontal, 30)
            )
    }
    
    private var playersHand: some View {
        GinPlayerHandView(
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
        .padding(.bottom, 40)
        .shadow(color: game.playerHasWon ? Color("winYellow") : .black.opacity(0.25), radius: handShadowRadius, x: (handShadowRadius - 5) / 2) //when handShadowRadius is 15 or 5 it results in offsets of 5 and 0
        .onAppear {
            if game.playerHasWon {
                withAnimation(.linear(duration: 1).speed(motionSpeed)) {
                    handShadowRadius = 15
                }
            }
        }
        .onChange(of: game.playerHasWon) { _, hasWon in
            if hasWon {
                withAnimation(.linear(duration: 0.33).speed(motionSpeed)) {
                    handShadowRadius = 15
                }
            } else { //is this else necessary? its initialized to 0 anyway
                handShadowRadius = 5
            }
        }
        .zIndex(1)
    }
    
    
    // MARK: - Helper functions
    private func animateOpponentsTurn() async { //modifies backend, which triggers animation in opponentHandView
        guard game.phase == .animationPhase || game.isAnimatingOpponentTurn else {
            game.hasPerformedInitialLoad = true
            return
        }
        if game.opponentDrewFromDeck {
            game.opponentDrawFromDeck()
        } else {
            game.opponentDrawFromDiscard()
        }
        do { try await Task.sleep(nanoseconds: 1_300_000_000) } catch { } // wait for draw (0.7s) + discard (0.5s) animations
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
        if discardFrame.contains(location) {
            isHoveringDiscard = true
        } else {
            isHoveringDiscard = false
        }
    }

    private func handleDragEnded(card: Card, location: CGPoint) {
        if discardFrame.contains(location) {
            if game.phase == .discardPhase {
                game.discardCard(card: card)
            } else {
                HapticManager.instance.playErrorFeedback()
            }
        } else {
            //print("Drop → No zone, card returns")
        }
        isHoveringDiscard = false
        
    }
    
}

enum DrawSource {
    case deck
    case discard
    case none
}
