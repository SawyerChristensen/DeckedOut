//
//  GinTranscriptV2.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 2/1/26.
//

import SwiftUI

struct GinTranscriptV2: View {
    let gameState: GinRummyV2GameState
    let localParticipantID: UUID
    var onHeightChange: ((CGFloat) -> Void)? = nil

    private var mySeatIndex: Int? { gameState.seats.firstIndex(of: localParticipantID) }
    private var playersHand: [Card] {
        guard let idx = mySeatIndex, idx < gameState.hands.count else { return [] }
        return gameState.hands[idx]
    }
    private var isMyTurn: Bool {
        guard let idx = mySeatIndex else { return false }
        return gameState.currentSeatIndex == idx
    }

    private var playerWon: Bool { GinRummyValidator.canMeldAllCards(hand: playersHand) }
    private var opponentWon: Bool {
        gameState.hands.enumerated().contains { i, hand in i != mySeatIndex && GinRummyValidator.canMeldAllCards(hand: hand) }
    }
    private var winningOpponentHand: [Card] {
        gameState.hands.enumerated().first { i, hand in i != mySeatIndex && GinRummyValidator.canMeldAllCards(hand: hand) }?.element ?? []
    }

    var body: some View {
        VStack {
            Color.clear
                .frame(height: 150)
                .overlay {
                    if playersHand != [] {
                        GinTranscriptPlayerHand(cards: opponentWon ? winningOpponentHand : playersHand, playerWon: playerWon, opponentWon: opponentWon)
                            .offset(y: opponentWon ? -30 : 50)
                    }
                }

            CaptionTextView(isWaiting: !isMyTurn, altText: opponentWon || playerWon ? "I won in Gin!" : "Your turn in Gin!")
            
        }
        .background( //for measuring & reporting the view height
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        onHeightChange?(geometry.size.height)
                    }
                    .onChange(of: geometry.size.height) { _, newHeight in
                        onHeightChange?(newHeight)
                    }
            }
        )
        .background(FeltBackgroundView())
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text("Gin", comment: "VoiceOver accessibility label for the Gin game transcript bubble"))
        .accessibilityInputLabels([
            Text("Gin", comment: "Voice Control input label – Gin game transcript bubble"),
            Text("Gin Rummy", comment: "Voice Control input label – alternative name for the Gin game"),
            Text("Card Game", comment: "Voice Control input label – generic phrase for a card game"),
            Text("Gin game", comment: "Voice Control input label – Gin game transcript bubble"),
            Text("Gin Rummy game", comment: "Voice Control input label – Gin game transcript bubble"),
            Text("Gin card game", comment: "Voice Control input label – Gin game transcript bubble"),
            Text("Gin Rummy card game", comment: "Voice Control input label – Gin game transcript bubble"),
            Text("Open card game", comment: "Voice Control input label – open the card game from the transcript bubble"),
        ])
    }
}
