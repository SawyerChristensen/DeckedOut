//
//  Crazy8sRootView.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 2/23/26.
//

import Foundation
import SwiftUI

struct Crazy8sRootView: View {
    @ObservedObject var game: Crazy8sManager

    init(game: Crazy8sManager) {
        self.game = game
    }

    var body: some View {
        if game.needsToJoin || game.isSettlingAfterJoin {
            JoinGameView(
                game: game,
                needsToJoin: game.needsToJoin,
                currentPlayers: game.seats.filter { $0 != Crazy8sManager.unclaimedSeat }.count,
                maxPlayers: game.seats.count
            )

        } else { //we do not need to join. the game is loaded. display it
            Crazy8sGameView()
                .environmentObject(game)
                .id(game.sessionID) // Rebuild the whole game subtree when a new session loads
        }
    }
}
