//
//  Crazy8sTranscriptInvite.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 2/23/26.
//

import SwiftUI

struct Crazy8sTranscriptInvite: View {
    var gameState: Crazy8sV2GameState? = nil
    var inviterCardBackOverride: String? = nil //used by the legacy 1v1 path where gameState isn't passed in
    var onHeightChange: ((CGFloat) -> Void)? = nil
    
    private var joinedPlayerCount: Int { gameState?.seats.filter { $0 != Crazy8sManager.unclaimedSeat }.count ?? 0 }
    private var totalPlayerCount: Int { gameState?.seats.count ?? 0 }
    private var isWaitingForPlayers: Bool {
        guard gameState != nil else { return false } // If there is no V2 game state, we aren't waiting for group chat players
        return joinedPlayerCount < totalPlayerCount
    }
    private var inviterCardBack: String? {
        if let override = inviterCardBackOverride { return override }
        guard let backs = gameState?.seatCardBacks, joinedPlayerCount > 0 else { return nil }
        let idx = joinedPlayerCount - 1
        return backs.indices.contains(idx) ? backs[idx] : nil
    }
    // Prefer the payload variant; the legacy 1v1 invite path carries no state, so fall back to region.
    private var variant: Crazy8sVariant { gameState?.variant ?? Crazy8sVariant.forCurrentRegion() }
    private var inviteCaption: String {
        String(localized: "Let's Play \(variant.displayName)!", comment: "Crazy 8s invite caption/summary, %@ is the game/variant name")
    }

    var body: some View {
        VStack() {
            
            Crazy8sTranscriptInviteHand(cardBackName: inviterCardBack, variant: variant)
                .offset(y: 40)
                .frame(height: 150)
                .overlay(alignment: .top) {
                    if isWaitingForPlayers {
                        Text("Joined: \(joinedPlayerCount) / \(totalPlayerCount)")
                            .font(.system(.headline, design: .serif, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.top, )
                    }
                }
                
            CaptionTextView(isWaiting: false, altText: inviteCaption, altTextIsLocalized: true) //technically the player IS waiting, but that bool is to display "waiting for opponent..." or not
            
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
            Text("Crazy 8s Invite", comment: "Voice Control input label – Crazy 8s game invite transcript bubble"),
            Text("Crazy 8s Game Invite", comment: "Voice Control input label – Crazy 8s game invite transcript bubble"),
            Text("Crazy 8s card game", comment: "Voice Control input label – Crazy 8s game transcript bubble"),
            Text("Open card game", comment: "Voice Control input label – open the card game from the transcript bubble"),
        ])
    }
}
