//
//  GinRootView.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 11/26/25.
//

import Foundation
import SwiftUI

//Establishes GameManager as a single source of truth
struct GinRootView: View {
    @ObservedObject var game: GinRummyManager
    
    init(game: GinRummyManager) {
        self.game = game
    }

    var body: some View {
        GinGameView()
            .environmentObject(game)
    }
}
