//
//  GolfRootView.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 4/15/26.
//

import Foundation
import SwiftUI

struct GolfRootView: View {
    @ObservedObject var game: GolfManager

    init(game: GolfManager) {
        self.game = game
    }

    var body: some View {
        if game.needsToJoin || game.isSettlingAfterJoin {
            JoinGameView(
                game: game,
                needsToJoin: game.needsToJoin,
                currentPlayers: game.seats.filter { $0 != GolfManager.unclaimedSeat }.count,
                maxPlayers: game.seats.count
            )

        } else {
            GolfGameView()
                .environmentObject(game)
        }
    }
}

