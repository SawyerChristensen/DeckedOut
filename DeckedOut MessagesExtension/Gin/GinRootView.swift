//
//  GinRoot.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 11/26/25.
//

import Foundation
import SwiftUI

//Establishes GameManager as a single source of truth
struct GinRootView: View {
    @StateObject private var game = GameManager()

    var body: some View {
        GinGameView()
            .environmentObject(game)
    }
}
