//
//  GinTranscriptInvite.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 2/6/26.
//

import SwiftUI

struct GinTranscriptInvite: View {
    var gameState: GinRummyV2GameState? = nil
    var onHeightChange: ((CGFloat) -> Void)? = nil

    private var joinedPlayerCount: Int { gameState?.seats.filter { $0 != GinRummyManager.unclaimedSeat }.count ?? 0 }
    private var totalPlayerCount: Int { gameState?.seats.count ?? 0 }
    private var isWaitingForPlayers: Bool {
        guard gameState != nil else { return false }
        return joinedPlayerCount < totalPlayerCount
    }

    var body: some View {
        VStack() {

            GinTranscriptInviteHand()
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
        .background(Image("feltBackgroundLight")
            .resizable()
            .aspectRatio(contentMode: .fill)
        )
    }
}
