//
//  HandMetrics.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 9/17/26.
//

import CoreGraphics
import SwiftUI

/// Card sizing for a fanned hand, solved against the width actually on screen.
///
/// Every fanned hand in the app (Crazy 8s, Gin, the opponent arcs) lays its cards out as an `HStack`
/// of overlapping cards, each rotated a little further than its neighbour. That means the hand's real
/// footprint is *not* the `HStack`'s width: rotating the end card about its own centre pushes it
/// further out again. The old sizing ignored both facts — it hard-coded 105×150 with a −66 overlap and
/// shrank only once the hand passed nine cards — so a ten- or eleven-card hand ran clean off both
/// edges of the screen.
///
/// So the sizing is solved instead of guessed. For `count` cards of width `w` the fan spans
///
///     (count − 1) × sliverRatio × w  +  w·cos(edge)  +  (w / aspect)·sin(edge)
///
/// where `edge` is the outermost card's fan angle. `metrics(count:availableWidth:)` picks the largest
/// cards that fit that budget, in the order a card player would: full size and full spacing first, then
/// a tighter overlap, and only then smaller cards.
enum HandMetrics {
    /// Card height when the hand fits comfortably — the size every hand used to render at.
    static let fullHeight: CGFloat = 150
    /// Cards never shrink below this, even if the hand then overflows (see `metrics(count:availableWidth:scale:)`).
    static let minHeight: CGFloat = 80
    /// Playing-card aspect ratio; width = height × this. Matches `CardView`'s `.aspectRatio(0.7)`.
    static let aspect: CGFloat = 0.7
    /// Card width at `fullHeight`.
    static var fullWidth: CGFloat { fullHeight * aspect }

    /// Visible sliver of each overlapped card as a fraction of card width. `0.371` is 39pt of a 105pt
    /// card — the old un-compressed hand exactly (105 wide, −66 spacing).
    static let fullSliverRatio: CGFloat = 39.0 / 105.0
    /// The tightest the fan is allowed to close up. Below roughly a fifth of the card, the rank and
    /// suit in the corner index start disappearing under the next card.
    static let minSliverRatio: CGFloat = 0.22

    /// Degrees of fan between neighbouring cards in a small hand.
    static let fanDegreesPerCard: Double = 4
    /// Total fan spread, outermost card to outermost card. A big hand fans by less per card rather than
    /// splaying itself sideways off the table — every extra degree at the edge costs width twice over.
    static let maxFanSpread: Double = 32
    /// How far each card rides up (or down) per step away from the middle of the fan, at full size.
    static let fanRisePerCard: CGFloat = 5
    /// Breathing room left at each edge of the screen so the outermost card never kisses the bezel.
    static let edgeInset: CGFloat = 8

    struct Metrics {
        var width: CGFloat
        var height: CGFloat
        /// Negative — the `HStack` overlap between neighbouring cards.
        var spacing: CGFloat
        /// Degrees of fan between neighbouring cards.
        var fanStep: Double
        /// Y offset per step away from the middle of the fan.
        var riseStep: CGFloat
    }

    /// Sizing for a hand of `count` cards that has `availableWidth` points to live in.
    ///
    /// `scale` is the opponent-arc downscale (`1` for a hand rendered at its own size); pass the
    /// *unscaled* budget — i.e. divide the screen width by the same `scale` — so the hand is solved at
    /// full size and then shrunk as a whole.
    ///
    /// A hand of about twenty cards is the most that fits; beyond that the `minHeight` floor wins and
    /// the fan overflows rather than shrinking into unreadable confetti.
    static func metrics(count: Int, availableWidth: CGFloat, scale: CGFloat = 1) -> Metrics {
        let n = max(count, 1)
        let gaps = CGFloat(n - 1)

        let fanStep = n > 1 ? min(fanDegreesPerCard, maxFanSpread / Double(n - 1)) : 0
        let edge = fanStep * Double(n - 1) / 2 * .pi / 180
        // The end card is rotated about its own centre, so it reaches out by half of its rotated
        // bounding box rather than half its width — and it does so at both ends of the fan.
        let endCardSpan = CGFloat(cos(edge)) + CGFloat(sin(edge)) / aspect
        func footprint(_ sliverRatio: CGFloat) -> CGFloat { gaps * sliverRatio + endCardSpan }

        let budget = max(availableWidth - 2 * edgeInset, 1)

        var sliverRatio = fullSliverRatio
        var width = fullWidth

        if footprint(sliverRatio) * width > budget {
            // Close the fan up before shrinking the cards: solve footprint(r) × fullWidth == budget.
            if gaps > 0 {
                sliverRatio = (budget / fullWidth - endCardSpan) / gaps
                sliverRatio = min(fullSliverRatio, max(minSliverRatio, sliverRatio))
            }
            // Still too wide with the fan fully closed — now the cards themselves have to give.
            width = min(fullWidth, budget / footprint(sliverRatio))
            width = max(minHeight * aspect, width)
        }

        let sliver = width * sliverRatio
        return Metrics(
            width: width * scale,
            height: width / aspect * scale,
            spacing: (sliver - width) * scale,
            fanStep: fanStep,
            riseStep: fanRisePerCard * scale
        )
    }

    /// The width a fanned hand has to work with: the extension's own width on iPad, the screen on iPhone.
    static func availableWidth(extensionWidth: CGFloat) -> CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? extensionWidth : UIScreen.main.bounds.width
    }
}
