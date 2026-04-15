//
//  GolfRootView.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 4/15/26.
//

import Foundation
import SwiftUI

//Establishes GameManager as a single source of truth
struct GolfRootView: View {
    @ObservedObject var game: GolfManager
    
    init(game: GolfManager) {
        self.game = game
    }

    var body: some View {
        GolfGameView()
            .environmentObject(game)
    }
}
