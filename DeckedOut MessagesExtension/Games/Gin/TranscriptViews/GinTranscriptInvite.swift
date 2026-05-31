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
        .accessibilityLabel("Gin")
        .accessibilityInputLabels(["Gin", "Gin Rummy", "Card Game", "Gin game", "Gin Rummy game", "Gin Rummy Invite", "Gin Rummy Game Invite", "Gin card game", "Gin Rummy card game", "Open card game"])
    }
}
