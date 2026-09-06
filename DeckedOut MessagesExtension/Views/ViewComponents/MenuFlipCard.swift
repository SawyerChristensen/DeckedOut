//
//  MenuFlipCard.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 9/6/26.
//

import SwiftUI

/// One physical card in the main menu's hand.
///
/// The menu is a single hand of cards that turns over in place. At rest it shows the equipped
/// theme's card back, with the centre card turned face up onto the current game; opening the theme
/// picker turns every card in that same hand over onto a theme's card back. Nothing is stacked
/// behind anything and nothing cross-fades — there is one hand, and it flips.
///
/// That only reads as a flip if a card's artwork changes at exactly the moment the card is edge-on,
/// and the only way to guarantee that in SwiftUI is to make one interpolated value responsible for
/// both. `MenuFlipCard` is `Animatable`, so SwiftUI re-runs this body on every frame of a flip with
/// the in-between values of `spin` and `menuFlip`; the rotation, which face is pointing at the
/// viewer, and which artwork that face carries all fall out of those two numbers in the same
/// evaluation. They cannot drift apart, however the flip was started or interrupted.
///
/// The design this replaced stacked a second, independent hand behind the first and swapped which
/// one was opaque at the halfway point — a cross-fade wearing a flip's clothes. Correctness there
/// depended on a wheel-level `FlipOpacity`, two more inside every card, and 21 separate rotations
/// all agreeing on when "halfway" was. They didn't: a card left mid-settle by a swipe crossed 90° a
/// beat behind the wheel it lived in and went on showing a game title card after the theme cards
/// had already begun turning in. Every card in the game hand carried a title card on its front
/// face, so *any* desync at all put the wrong artwork on screen.
struct MenuFlipCard: View, Animatable {
    /// The card's own resting turn: 0 when it is the face-up card at the centre of the fan, 180 when
    /// it is face down in the hand. Changes as the wheel is scrolled.
    var spin: Double
    /// How far the menu has turned over into the theme picker, shared by every card in the hand.
    /// Magnitude runs 0 to 180; the *sign* is which way round the hand turns, and it is the caller's
    /// to choose (see `MenuCardWheel`, which turns the same way the header title does).
    ///
    /// Total rotation is `spin + menuFlip`, and because `spin` is always either 0 or 180, every card
    /// is exactly edge-on when this passes 90° of turn — which is what makes swapping the artwork
    /// there invisible, for all 21 cards at once.
    var menuFlip: Double

    /// What this slot shows while the menu is on the games side: the game on the face-up card, and
    /// `equippedBackName` on the face-down ones.
    let game: MenuGame
    /// What this slot shows once the hand has turned over into the picker — on both faces, so the
    /// card reads as one solid theme however far round it happens to be.
    let themeBackName: String
    /// The equipped theme's card back: the back of every card in the hand on the games side.
    let equippedBackName: String
    let cardHeight: CGFloat

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(spin, menuFlip) }
        set {
            spin = newValue.first
            menuFlip = newValue.second
        }
    }

    var body: some View {
        let rotation = spin + menuFlip
        // Which way the card is facing, read off the live rotation rather than off the state that
        // asked for it — the two are the same number here, which is the entire point.
        let facingFront = abs(rotation.remainder(dividingBy: 360)) < 90
        // Whether the hand has turned far enough that its artwork belongs to the picker. Every card
        // is edge-on at this crossing, so nothing is on screen to see the swap happen. Measured on
        // the magnitude, so which way the hand turns is purely `menuFlip`'s sign to decide.
        let showsThemes = abs(menuFlip) >= 90

        Group {
            if facingFront {
                face(showsThemes: showsThemes, isFront: true)
            } else {
                face(showsThemes: showsThemes, isFront: false)
                    // The card is turned away from us, so its artwork would be drawn mirrored —
                    // turn the artwork itself back round to cancel that out.
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            }
        }
        .frame(height: cardHeight)
        .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0))
    }

    @ViewBuilder
    private func face(showsThemes: Bool, isFront: Bool) -> some View {
        if showsThemes {
            cardImage(themeBackName)
        } else if isFront {
            Image(uiImage: game.logoImage)
                .resizable()
                .aspectRatio(0.7, contentMode: .fit)
        } else {
            cardImage(equippedBackName)
        }
    }

    private func cardImage(_ name: String) -> some View {
        Image(name)
            .resizable()
            .aspectRatio(0.7, contentMode: .fit)
    }
}
