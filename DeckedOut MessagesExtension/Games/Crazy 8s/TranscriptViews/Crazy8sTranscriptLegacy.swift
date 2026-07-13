//
//  Crazy8sTranscriptLegacy.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 5/6/26.
//

import SwiftUI

struct Crazy8sTranscriptLegacy: View {
    let gameState: Crazy8sLegacyGameState
    let isFromMe: Bool
    var onHeightChange: ((CGFloat) -> Void)? = nil

    private var playersHand: [Card] { isFromMe ? gameState.senderHand : gameState.receiverHand }
    private var opponentsHand: [Card] { isFromMe ? gameState.receiverHand : gameState.senderHand }
    private var playerWon: Bool { playersHand.count == 0 }
    private var opponentWon: Bool { opponentsHand.count == 0 }
    // Name follows the payload variant so every participant sees the same game name.
    private var variant: Crazy8sVariant { gameState.variant ?? .crazy8s }
    private var caption: String {
        let name = variant.displayName
        return (playerWon || opponentWon)
            ? String(localized: "I won in \(name)!", comment: "Crazy 8s template win caption/summary, %@ is the game/variant name")
            : String(localized: "Your turn in \(name)!", comment: "Crazy 8s template message caption, %@ is the game/variant name")
    }

    var body: some View {
        VStack {

            if playerWon || opponentWon {
                GameOverTranscriptView(playerWon: playerWon)
                
            } else {
                Color.clear
                    .frame(height: 150)
                    .overlay { //the crazy 8s player hand expands. making it an overlay means its width expansion does not bubble up and effect the VStacks width
                        Crazy8sTranscriptPlayerHand(cards: playersHand, variant: variant)
                            .offset(y: opponentWon ? -30 : 50)
                    }
            }

            CaptionTextView(isWaiting: isFromMe, altText: caption, altTextIsLocalized: true, isFinalOverride: opponentWon || playerWon)
            
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
        .accessibilityLabel(Text(verbatim: variant.displayName))
        .accessibilityInputLabels([
            Text("Crazy 8s", comment: "Voice Control input label – Crazy 8s game transcript bubble"),
            Text("Card Game", comment: "Voice Control input label – generic phrase for a card game"),
            Text("Crazy 8s game", comment: "Voice Control input label – Crazy 8s game transcript bubble"),
            Text("Crazy 8s card game", comment: "Voice Control input label – Crazy 8s game transcript bubble"),
            Text("Open card game", comment: "Voice Control input label – open the card game from the transcript bubble"),
        ])
    }
}
