//
//  GinTranscriptInvite.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 2/6/26.
//

import SwiftUI

struct GinTranscriptInvite: View {
    var gameState: GinRummyV2GameState? = nil
    var inviterCardBackOverride: String? = nil //used by the legacy 1v1 path where gameState isn't passed in
    var onHeightChange: ((CGFloat) -> Void)? = nil

    private var joinedPlayerCount: Int { gameState?.seats.filter { $0 != GinRummyManager.unclaimedSeat }.count ?? 0 }
    private var totalPlayerCount: Int { gameState?.seats.count ?? 0 }
    private var isWaitingForPlayers: Bool {
        guard gameState != nil else { return false }
        return joinedPlayerCount < totalPlayerCount
    }
    private var inviterCardBack: String? {
        if let override = inviterCardBackOverride { return override }
        guard let backs = gameState?.seatCardBacks, joinedPlayerCount > 0 else { return nil }
        let idx = joinedPlayerCount - 1
        return backs.indices.contains(idx) ? backs[idx] : nil
    }

    var body: some View {
        VStack() {

            GinTranscriptInviteHand(cardBackName: inviterCardBack)
                .offset(y: 40)
                .frame(height: 150)
                .overlay(alignment: .top) {
                    if isWaitingForPlayers {
                        Text("Joined: \(joinedPlayerCount) / \(totalPlayerCount)")
                            .font(.system(.headline, design: .serif, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.top)
                    }
                }

            CaptionTextView(isWaiting: false, altText: "Let's Play Gin!") //technically the player IS waiting, but that bool is to display "waiting for opponent..." or not
            
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
        .accessibilityLabel(Text("Gin", comment: "VoiceOver accessibility label for the Gin game invite transcript bubble"))
        .accessibilityInputLabels([
            Text("Gin", comment: "Voice Control input label – Gin game transcript bubble"),
            Text("Gin Rummy", comment: "Voice Control input label – alternative name for the Gin game"),
            Text("Card Game", comment: "Voice Control input label – generic phrase for a card game"),
            Text("Gin game", comment: "Voice Control input label – Gin game transcript bubble"),
            Text("Gin Rummy game", comment: "Voice Control input label – Gin game transcript bubble"),
            Text("Gin Rummy Invite", comment: "Voice Control input label – Gin game invite transcript bubble"),
            Text("Gin Rummy Game Invite", comment: "Voice Control input label – Gin game invite transcript bubble"),
            Text("Gin card game", comment: "Voice Control input label – Gin game transcript bubble"),
            Text("Gin Rummy card game", comment: "Voice Control input label – Gin game transcript bubble"),
            Text("Open card game", comment: "Voice Control input label – open the card game from the transcript bubble"),
        ])
    }
}
