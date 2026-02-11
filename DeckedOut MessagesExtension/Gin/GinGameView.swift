//
//  GinRummy.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 11/17/25.
//

import Foundation
import SwiftUI

struct GinGameView: View {
    @EnvironmentObject var game: GameManager
    @Environment(\.colorScheme) var colorScheme
    
    @State private var deckFrame: CGRect = .zero
    @State private var discardFrame: CGRect = .zero
    @State private var lastDrawSource: DrawSource = .none
    @State private var isHoveringDiscard: Bool = false

    var body: some View {
        ZStack {

            Image(colorScheme == .dark ? "feltBackgroundDark" : "feltBackgroundLight") //The Background
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
            
            VStack {
                // Opponent's Hand
                OpponentHandView(cards: game.opponentHand, discardPileZone: discardFrame, deckZone: deckFrame) //maybe replace isFaceUp here and in player hand...
                //.shadow(color: game.opponentHasWon ? .yellow : .yellow.opacity(0.0), radius: 20 )
                    .padding(.top, 30)
                    .zIndex(2)
                
                Spacer()
                
                // Middle section
                HStack {
                    Spacer()
                    Spacer()
                    Spacer()
                    
                    ZStack {// Deck
                        ForEach(0..<5) { i in
                            Image("cardBackRed")
                                .resizable()
                                .aspectRatio(0.7, contentMode: .fit)
                                .frame(height: 145)
                                .offset(x: CGFloat(-i) * 3, y: CGFloat(-i) * 3)
                                .shadow(radius: i == 4 ? 1 : 8)
                                .background {
                                    if i == 4 { //4 is top card, the stack proceeds up-left, not down-right
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
                    .onTapGesture {
                        if game.phase == .drawPhase {
                            game.drawFromDeck()
                            lastDrawSource = .deck
                            SoundManager.instance.playCardDeal()
                        } else {
                            SoundManager.instance.playErrorFeedback()
                        }
                    }
                    
                    Spacer()
                    Spacer()
                    
                    ZStack { // Discard Pile Container
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
                                .onTapGesture {
                                    if game.phase == .drawPhase {
                                        game.drawFromDiscard()
                                        lastDrawSource = .discard
                                        SoundManager.instance.playCardDeal()
                                    } else {
                                        SoundManager.instance.playErrorFeedback()
                                    }
                                }
                                .shadow(color: game.phase == .discardPhase && isHoveringDiscard ? .white : .black.opacity(0.2),
                                        radius: game.phase == .discardPhase && isHoveringDiscard ? 15 : 5)
                                .scaleEffect(game.phase == .discardPhase && isHoveringDiscard ? 1.05 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: isHoveringDiscard)
                        } else { // display an outline of where a discarded card *should* go
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 2)
                                .frame(width: 101.5, height: 145)
                        }
                    }
                    
                    Spacer()
                    Spacer()
                    Spacer()
                }
                //.padding(.horizontal, 80)
                .zIndex(1)
                
                Spacer()
                
                // Player's hand
                PlayerHandView(
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
                .shadow(color: game.playerHasWon ? .yellow : .black.opacity(0.25), radius: game.playerHasWon ? 15 : 5, x: game.playerHasWon ? 5 : 0)
                .offset(x: 5)
                .zIndex(1)
                
            }
        }
        .overlay {
            if game.phase == .idlePhase {
                WaitingOverlayView()
                    .transition(.opacity.animation(.easeInOut(duration: 0.5)))
            }
            else if game.phase == .gameEndPhase {
                WinScreenView()
                    .transition(.opacity.animation(.easeInOut(duration: 0.5)))
            }
        }
        .task { //triggers every view reinit! our presentGameView currently blocks rebuilding if the game is already presented
            if !game.hasPerformedInitialLoad{
                do {
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                } catch { }
            }
            
            animateOpponentsTurn()
        }
    }
    
    //MARK: - Game View Helper functions (technically global scope)
    func animateOpponentsTurn() { //modifies backend, which triggers animation in opponentHandView
        if game.opponentDrewFromDeck {
            game.opponentDrawFromDeck()
        } else {
            game.opponentDrawFromDiscard()
        }
        game.hasPerformedInitialLoad = true
        //animating discard is automatically handled in opponents hand view
    }
    
    func calculateProperDeckZone(from frame: CGRect) -> CGRect {
        var newFrame = frame
        let topIndex = 4
        let offsetPerCard: CGFloat = -2
        
        let totalOffset = CGFloat(topIndex) * offsetPerCard
        
        newFrame.origin.x += totalOffset
        newFrame.origin.y += totalOffset * 4.5
        
        return newFrame
    }
    
    func handleDragChanged(card: Card, location: CGPoint) {
        if discardFrame.contains(location) {
            isHoveringDiscard = true
        } else {
            isHoveringDiscard = false
        }
    }

    func handleDragEnded(card: Card, location: CGPoint) {
        if discardFrame.contains(location) {
            if game.phase == .discardPhase {
                game.discardCard(card: card)
            } else {
                SoundManager.instance.playErrorFeedback()
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
