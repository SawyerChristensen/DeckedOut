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

    var body: some View {
        VStack() {
            
            Crazy8sTranscriptInviteHand(cardBackName: inviterCardBack)
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
                
            CaptionTextView(isWaiting: false, altText: "Let's Play Crazy 8s!") //technically the player IS waiting, but that bool is to display "waiting for opponent..." or not
            
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
        .accessibilityLabel("Crazy 8s")
        .accessibilityInputLabels(["Crazy 8s", "Card Game", "Crazy 8s game", "Crazy 8s Invite", "Crazy 8s Game Invite", "Crazy 8s card game", "Open card game"])
    }
}
