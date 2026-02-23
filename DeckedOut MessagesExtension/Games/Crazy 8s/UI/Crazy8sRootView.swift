//
//  Crazy8sRootView.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 2/23/26.
//

import Foundation
import SwiftUI

//Establishes GameManager as a single source of truth
struct Crazy8sRootView: View {
    @ObservedObject var game: Crazy8sManager
    
    init(game: Crazy8sManager) {
        self.game = game
    }

    var body: some View {
        Crazy8sGameView()
            .environmentObject(game)
    }
}
