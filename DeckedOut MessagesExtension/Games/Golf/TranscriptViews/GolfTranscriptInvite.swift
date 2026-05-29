//
//  GolfTranscriptInvite.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 4/15/26.
//

import SwiftUI

struct GolfTranscriptInvite: View {
    var gameState: GolfV2GameState? = nil
    var onHeightChange: ((CGFloat) -> Void)? = nil

    private var joinedPlayerCount: Int { gameState?.seats.filter { $0 != GolfManager.unclaimedSeat }.count ?? 0 }
    private var totalPlayerCount: Int { gameState?.seats.count ?? 0 }
    private var isWaitingForPlayers: Bool {
        guard gameState != nil else { return false }
        return joinedPlayerCount < totalPlayerCount
    }

    var body: some View {
        VStack() {

            GolfTranscriptInviteHand()
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

            CaptionTextView(isWaiting: false, altText: "Let's Play Golf!") //technically the player IS waiting, but that bool is to display "waiting for opponent..." or not
            
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
        .accessibilityLabel("Golf")
        .accessibilityInputLabels(["Golf", "Card Game", "Golf game", "Golf Invite", "Golf Game Invite", "Golf card game", "Open card game"])
    }
}
