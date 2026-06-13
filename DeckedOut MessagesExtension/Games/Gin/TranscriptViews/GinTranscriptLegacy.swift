//
//  GinTranscriptLegacy.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 2/1/26.
//

import SwiftUI

struct GinTranscriptLegacy: View {
    let gameState: GinRummyGameState
    let isFromMe: Bool
    var onHeightChange: ((CGFloat) -> Void)? = nil
    
    private var playersHand: [Card] { isFromMe ? gameState.senderHand : gameState.receiverHand }
    private var opponentsHand: [Card] { isFromMe ? gameState.receiverHand : gameState.senderHand }
    private var playerWon: Bool {
        if let roundWinner = gameState.roundWinner {
            if isFromMe {
                return roundWinner == .sender
            }
            return roundWinner == .receiver
        }
        return GinRummyValidator.canMeldAllCards(hand: playersHand)
    }
    private var opponentWon: Bool {
        if let roundWinner = gameState.roundWinner {
            if isFromMe {
                return roundWinner == .receiver
            }
            return roundWinner == .sender
        }
        return GinRummyValidator.canMeldAllCards(hand: opponentsHand)
    }
    
    var body: some View {
        VStack {
            
            Color.clear
                .frame(height: 150)
                .overlay { //the crazy 8s player hand expands. making it an overlay means its width expansion does not bubble up and effect the VStacks width
                    GinTranscriptPlayerHand(cards: opponentWon ? opponentsHand : playersHand, playerWon: playerWon, opponentWon: opponentWon, opponentCardBack: isFromMe ? nil : gameState.senderCardBack)
                        .offset(y: opponentWon ? -30 : 50)
                }
                
            CaptionTextView(isWaiting: isFromMe, altText: opponentWon || playerWon ? "I won in Gin!" : "Your turn in Gin!")
            
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
