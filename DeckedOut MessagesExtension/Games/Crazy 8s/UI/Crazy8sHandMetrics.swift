//
//  Crazy8sHandMetrics.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 9/2/26.
//

import CoreGraphics

/// Card sizing for a Crazy 8s hand.
///
/// The hand renders at full size through `fullSizeCount` cards. Past that, every extra card eases the
/// cards a little smaller and the overlap a little tighter — a linear ramp, one step per card — until
/// it bottoms out at `floorCount`. Crazy 8s hands grow unbounded (ordinary draws, stacked draw-twos),
/// so this keeps a runaway hand from marching straight off the screen instead of shrinking exactly
/// once at 10 and never again.
///
/// Gin deliberately does *not* use this: a Gin hand is only ever `handSize` or `handSize + 1` cards,
/// so it stays a fixed 150pt.
enum Crazy8sHandMetrics {
    /// Card height at or below `fullSizeCount` cards. With `aspect` and `fullSliver` this reproduces
    /// the old un-compressed hand exactly: 105 wide, −66 spacing.
    static let fullHeight: CGFloat = 150
    /// Card height at or beyond `floorCount` cards.
    static let floorHeight: CGFloat = 122
    /// Visible width of each overlapped card (`width + spacing`) at full size…
    static let fullSliver: CGFloat = 39
    /// …and at the floor. Stays comfortably positive so the fan always reads left-to-right.
    static let floorSliver: CGFloat = 18
    /// Playing-card aspect ratio; width = height × this. Matches `CardView`'s `.aspectRatio(0.7)`.
    static let aspect: CGFloat = 0.7

    /// Full size holds through this many cards (Crazy 8s deals 5–7 to start).
    static let fullSizeCount = 9
    /// The ramp bottoms out here; any more cards than this render at the floor.
    static let floorCount = 20

    struct Metrics {
        var width: CGFloat
        var height: CGFloat
        var spacing: CGFloat   // negative — the HStack overlap between neighbouring cards
    }

    /// Sizing for a hand of `count` cards, every dimension multiplied by `scale` — the opponent-arc
    /// downscale (`1` for the player's own hand).
    static func metrics(count: Int, scale: CGFloat = 1) -> Metrics {
        let clamped = min(max(count, fullSizeCount), floorCount)
        let progress = CGFloat(clamped - fullSizeCount) / CGFloat(floorCount - fullSizeCount)

        let height = fullHeight - (fullHeight - floorHeight) * progress
        let sliver = fullSliver - (fullSliver - floorSliver) * progress
        let width  = height * aspect

        return Metrics(
            width:   width * scale,
            height:  height * scale,
            spacing: (sliver - width) * scale
        )
    }
}
