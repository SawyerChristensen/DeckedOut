//
//  FeltBackgroundView.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 5/27/26.
//

import SwiftUI

/// Shared felt background used across all game views, transcripts, menus, and overlays.
struct FeltBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    
    var inGame: Bool = false

    private var useDarkBackground: Bool {
        (colorScheme == .dark && inGame) || colorSchemeContrast == .increased
    }

    var body: some View {
        ZStack(alignment: .top) {
            Image(useDarkBackground ? "feltBackgroundDark" : "feltBackgroundLight")
                .resizable()
                .scaledToFill()
                .frame(
                    width: UIScreen.main.bounds.width,
                    height: UIScreen.main.bounds.height,
                    alignment: .top
                )
                .clipped()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
