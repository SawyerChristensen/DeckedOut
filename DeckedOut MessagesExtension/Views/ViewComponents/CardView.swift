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
            
            
            // FRONT VIEW — the front swaps instantly when `resolvedFrontName` changes (cross-fade
            // disabled for now).
            ZStack {
                if let frontUIImage {
                    Image(uiImage: frontUIImage)
                        .resizable()
                        .aspectRatio(0.7, contentMode: .fit)
                } else {
                    Image(resolvedFrontName)
                        .resizable()
                        .aspectRatio(0.7, contentMode: .fit)
                }
            }
            .frame(height: cardHeight)
            .modifier(FlipOpacity(rotation: rotation))
        }
        .rotation3DEffect(
            .degrees(rotation),
            axis: (x: 0.0, y: 1.0, z: 0.0) // Rotate around Y-axis
        )
    }
}

/// The top card of a discard pile, whose front cross-fades from a discarding opponent's theme into
/// the local player's equipped theme as the opponent's turn ends and the player's begins.
///
/// Game-agnostic: any game's discard pile can drop this in place of a bare `CardView`. The base card
/// always renders `frontImage` under the local player's theme; when `crossfadeFromBack` is set to a
/// discarding opponent's card-back name, the same card is briefly laid on top under *that* back's
/// theme and faded out — so the front dissolves from the opponent's artwork into the player's, and
/// the background never bleeds through mid-transition. The trigger is one-shot: this view consumes
/// (nils out) `crossfadeFromBack` as it begins the fade, so a manager only has to set it.
struct CrossfadingDiscardCard: View {
    var frontImage: String
    /// One-shot trigger, bound to the game manager. Set it to the discarding opponent's card-back
    /// name to start a fade; this view immediately resets it to `nil`.
    @Binding var crossfadeFromBack: String?
    var cardHeight: CGFloat = 145

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motionSpeed: Double { reduceMotion ? 0.66 : 1.0 }

    /// The opponent back currently laid over the top card, and its fading opacity. `token` guards the
    /// deferred cleanup so a rapid second discard doesn't clear a fresh fade.
    @State private var overlayBack: String? = nil
    @State private var overlayOpacity: Double = 1
    @State private var token: Int = 0

    var body: some View {
        ZStack {
            // Destination: the top card under the local player's equipped theme.
            CardView(frontImage: frontImage, cardHeight: cardHeight)

            // Source: the same card under the discarding opponent's theme, laid on top and faded out
            // so the front cross-fades into the player's theme. Present only during the brief window
            // after an opponent's card lands.
            if let overlayBack {
                CardView(frontImage: frontImage, backImageName: overlayBack, cardHeight: cardHeight)
                    .opacity(overlayOpacity)
            }
        }
        .onChange(of: crossfadeFromBack) { _, newBack in
            guard let newBack else { return }
            crossfadeFromBack = nil // one-shot: consume the trigger

            token += 1
            let current = token
            overlayBack = newBack
            overlayOpacity = 1
            withAnimation(.easeInOut(duration: 0.4).speed(motionSpeed)) {
                overlayOpacity = 0
            }
            // Remove the overlay once the fade completes (unless a newer fade has since started).
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4 / motionSpeed) {
                if token == current { overlayBack = nil }
            }
        }
    }
}
