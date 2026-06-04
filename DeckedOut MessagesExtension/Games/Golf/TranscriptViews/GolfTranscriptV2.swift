//
//  GolfTranscriptV2.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 4/15/26.
//

import SwiftUI

struct GolfTranscriptV2: View {
    let gameState: GolfV2GameState
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

    private var playerFaceUpIndices: Set<Int> {
        guard let idx = mySeatIndex, idx < gameState.faceUpIndices.count else { return [] }
        var faceUp = gameState.faceUpIndices[idx]
        let lastMover = (gameState.currentSeatIndex - 1 + gameState.seats.count) % gameState.seats.count
        if idx == lastMover, let replacedIdx = gameState.lastPlayerIndexReplaced {
            faceUp.insert(replacedIdx)
        }
        return faceUp
    }

    private var isLastRound: Bool {
        gameState.goingOutSeat != nil && !gameOver
    }

    private var gameOver: Bool {
        guard let goSeat = gameState.goingOutSeat else { return false }
        return gameState.currentSeatIndex == goSeat
    }

    private var playerWon: Bool {
        guard gameOver else { return false }
        guard let idx = mySeatIndex else { return false }
        let myScore = GolfManager.calculateScore(hand: playersHand)
        let otherScores = gameState.hands.enumerated()
            .filter { $0.offset != idx }
            .map { GolfManager.calculateScore(hand: $0.element) }
        let bestOtherScore = otherScores.min() ?? Int.max

        if idx == gameState.goingOutSeat {
            return myScore < bestOtherScore
        } else {
            return myScore <= bestOtherScore
        }
    }

    private var winMessage: String {
        playerWon ? "I won in Golf!" : "You won in Golf!"
    }

    // MARK: - The Transcript View
    var body: some View {
        VStack {
            if gameOver {
                GameOverTranscriptView(playerWon: playerWon)

            } else if playersHand != [] {
                GolfTranscriptPlayerHand(cards: playersHand, faceUpIndices: playerFaceUpIndices)
                    .offset(y: 6)
                    .frame(height: 150)
            } else { //should never trigger
                Color.clear
                    .frame(height: 150)
            }

            CaptionTextView(isWaiting: !isMyTurn, altText: gameOver ? winMessage : (isLastRound ? "Last turn in Golf!" : "Your turn in Golf!"))
        }
        .onAppear {
            if playerWon {
                WinTracker.shared.recordWinOnce(for: "Golf", sessionID: gameState.sessionID)
            }
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
        .accessibilityLabel(Text("Golf", comment: "VoiceOver accessibility label for the Golf game transcript bubble"))
        .accessibilityInputLabels([
            Text("Golf", comment: "Voice Control input label – Golf game transcript bubble"),
            Text("Card Game", comment: "Voice Control input label – generic phrase for a card game"),
            Text("Golf game", comment: "Voice Control input label – Golf game transcript bubble"),
            Text("Golf card game", comment: "Voice Control input label – Golf game transcript bubble"),
            Text("Open card game", comment: "Voice Control input label – open the card game from the transcript bubble"),
        ])
    }
}
