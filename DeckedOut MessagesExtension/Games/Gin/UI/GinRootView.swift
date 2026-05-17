//
//  GinRootView.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 11/26/25.
//

import Foundation
import SwiftUI

struct GinRootView: View {
    @ObservedObject var game: GinRummyManager

    init(game: GinRummyManager) {
        self.game = game
    }

    var body: some View {
        if game.needsToJoin || game.isSettlingAfterJoin {
            JoinGameView(
                game: game,
                needsToJoin: game.needsToJoin,
                currentPlayers: game.seats.filter { $0 != GinRummyManager.unclaimedSeat }.count,
                maxPlayers: game.seats.count
            )

        } else {
            GinGameView()
                .environmentObject(game)
        }
    }
}
