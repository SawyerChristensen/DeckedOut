//
//  CardView.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 1/2/26.
//

import SwiftUI

struct CardView: View { //where only one side is a (letter?)
    var frontImage: String = ""
    /// A pre-baked front bitmap (e.g. the main menu's composited game-logo cards). When set, it's
    /// drawn directly and the string-based theming/validation of `frontImage` is skipped — the card
    /// is already a flattened image, so there's no themed variant or asset name to resolve.
    var frontUIImage: UIImage? = nil
    var backLetter: String?
    var backImageName: String? = nil //custom card-back image; overrides the user's selected card back
    var cardHeight : CGFloat = 145
    var rotation: Double = 0 //default to face up
    /// When true (default), the front/back asset names are validated to exist in this build,
    /// falling back to defaults. This guards transcript/game views where a peer may send a name
    /// from a newer version. Set to `false` in trusted local contexts (the menu) where the assets
    /// are guaranteed present, to skip the main-thread `UIImage(named:)` existence check.
    var validatesAssetNames: Bool = true
    /// When true (default), `frontImage` is treated as an actual playing card (e.g. `aceClubs`)
    /// and the equipped theme's `fronts` suffix is applied to swap in its custom artwork.
    /// Set to `false` when `frontImage` is *not* a playing card — e.g. the menu's game-logo
    /// cards or a theme's card-back shown as a front — since those have no themed variant and
    /// would resolve to a missing asset (blank card) under a theme that defines `fronts`.
    var themesFront: Bool = true

    @ObservedObject private var cardBackSelection = CurrentTheme.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motionSpeed: Double { reduceMotion ? 0.66 : 1.0 }

    /// The previous front-image name during a cross-fade. While set, it's drawn *on top* of
    /// the current image with `fadingFrontOpacity` going 1 → 0 — so the new image is always
    /// fully visible underneath and the background never bleeds through mid-transition.
    @State private var fadingFrontName: String? = nil
    @State private var fadingFrontOpacity: Double = 0

    /// The resolved front asset name. Themed only for actual playing cards (`themesFront`);
    /// validated with fallback only when `validatesAssetNames`.
    ///
    /// When `backImageName` is set, the card belongs to someone else's deck (opponent), so the
    /// front theme is derived from *that* back's theme — never the local user's equipped theme.
    /// If the opponent's back doesn't match a known local theme, the front falls back to the
    /// default (un-themed) artwork.
    private var resolvedFrontName: String {
        guard themesFront else { return frontImage }
        if let backImageName {
            guard let suffix = DeckTheme.theme(forLogoCard: backImageName)?.fronts else { return frontImage }
            let themed = frontImage + suffix
            if !validatesAssetNames { return themed }
            return CurrentTheme.imageExists(themed) ? themed : frontImage
        }
        return validatesAssetNames ? cardBackSelection.frontName(for: frontImage)
                                   : cardBackSelection.themedFrontName(for: frontImage)
    }

    @ViewBuilder
    private var backImage: some View {
        if let letter = backLetter {
            LetterCardImage(character: letter, overrideCardBackName: backImageName)
        } else {
            let rawBack = backImageName ?? cardBackSelection.selectedName
            let backName = validatesAssetNames ? CurrentTheme.existingBackName(rawBack) : rawBack
            Image(backName)
                .resizable()
                .aspectRatio(0.7, contentMode: .fit)
        }
    }

    var body: some View {
        ZStack {
            // BACK VIEW
            backImage
                .frame(height: cardHeight)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .modifier(FlipOpacity(rotation: rotation + 180))
            
            
            // FRONT VIEW — cross-fades when `resolvedFrontName` changes (e.g. user swaps decks)
            // at the same speed/duration as the deck's back-to-back fade in the game views.
            ZStack {
                if let frontUIImage {
                    Image(uiImage: frontUIImage)
                        .resizable()
                        .aspectRatio(0.7, contentMode: .fit)
                } else {
                    Image(resolvedFrontName)
                        .resizable()
                        .aspectRatio(0.7, contentMode: .fit)
                        .id(resolvedFrontName)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.4).speed(motionSpeed), value: resolvedFrontName)
            .frame(height: cardHeight)
            .modifier(FlipOpacity(rotation: rotation))
        }
        .rotation3DEffect(
            .degrees(rotation),
            axis: (x: 0.0, y: 1.0, z: 0.0) // Rotate around Y-axis
        )
    }
}
