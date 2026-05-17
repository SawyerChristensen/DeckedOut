//
//  GinOpponentsArcView.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 5/10/26.
//

import SwiftUI

struct GinOpponentsArcView: View {
    @EnvironmentObject var game: GinRummyManager

    let discardPileZone: CGRect
    let deckZone: CGRect

    private var opponentCount: Int { max(game.seats.count - 1, 1) }

    private var opponentSeats: [Int] {
        guard game.seats.count > 2 else { return [] }
        var result: [Int] = []
        for i in 1..<game.seats.count {
            result.append((game.mySeatIndex + i) % game.seats.count)
        }
        return result
    }

    private var handScale: CGFloat { return 1.0 / sqrt(CGFloat(opponentCount)) } // 1 = 1.0, 2 = 0.71, 3 = 0.58, 4 = 0.5, 5 = 0.45...
    private var scaledCardHeight: CGFloat { 145 * handScale }
    private var screenWidth: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? game.extensionWidth : UIScreen.main.bounds.width
    }
    private var frameHeight: CGFloat {
        return (100 / handScale) + 20 // the addition for spacing beyond the arc
    }

    // MARK: 1v1 view
    var body: some View {
        if game.isSinglePlayer || game.seats.count <= 2 {
            GinOpponentHandView(
                cards: game.opponentHand,
                discardPileZone: discardPileZone,
                deckZone: deckZone
            )
        } else {
            multiOpponentArc
        }
    }

    // MARK: Groupchat view
    private var multiOpponentArc: some View {
        let seats = opponentSeats
        let count = seats.count
        let showAnimatedActive = (
            game.phase == .animationPhase ||
            game.phase == .drawPhase || //not completely sure why we need draw phase here
            game.isAnimatingOpponentTurn ||
            game.phase == .gameEndPhase && game.opponentHasWon)

        return ZStack {
            ForEach(Array(seats.enumerated()), id: \.element) { index, seatIndex in
                let pos = placement(for: index, count: count)
                let isActive = showAnimatedActive && seatIndex == game.animatingOpponentSeat

                Group {
                    if isActive {
                        GinOpponentHandView(
                            cards: game.opponentHand,
                            discardPileZone: discardPileZone,
                            deckZone: deckZone,
                            sizeScale: handScale,
                            handRotation: pos.rotation,
                        )
                    } else if seatIndex < game.allHands.count {
                        staticOpponentHand(cards: game.allHands[seatIndex])
                            .rotationEffect(.degrees(pos.rotation))
                    }
                }
                .offset(x: pos.x, y: pos.y)
                .zIndex(isActive ? 1 : 0)
            }
        }
        .frame(width: screenWidth, height: frameHeight)
    }

    // MARK: Placement
    private struct OpponentPlacement {
        let x: CGFloat       // horizontal offset from ZStack center
        let y: CGFloat       // vertical offset from ZStack center
        let rotation: Double // z-axis rotation in degrees, positive = clockwise
    }

    // Dynamic Distribution Rule:
    // N == 1: Center
    // N == 2: Sweeps from -45° to 45° to create a /\ shape
    // N >= 3: Sweeps from -90° to 90° to create a П shape, evenly spaced
    private func placement(for index: Int, count: Int) -> OpponentPlacement {
        if count == 1 {
            return OpponentPlacement(x: 0, y: 0, rotation: 0)
        }

        // 1. Determine the maximum angle spread
        let maxAngle: Double = count == 2 ? 60 : 90.0

        // 2. Calculate this specific opponent's angle mapping (theta)
        let fraction = Double(index) / Double(count - 1)
        let thetaDegrees = -maxAngle + fraction * (2 * maxAngle)
        let thetaRadians = thetaDegrees * .pi / 180.0

        // 3. Define the bounds of our elliptical arc
        let edgeInset: CGFloat = 30
        let rx = (screenWidth / 2) - (scaledCardHeight / 2) - edgeInset //width
        let ry = 70 / handScale //height
        
        // 4. Calculate the center pivot point (cy) for the ellipse
        // The top of the arc should sit near the top of the frame.
        let topY = (-frameHeight / 2) + (scaledCardHeight / 2) + 10
        let cy = topY + ry

        // 5. Calculate X and Y using parametric equation for an ellipse
        let x = rx * CGFloat(sin(thetaRadians))
        // We subtract from `cy` because in SwiftUI, smaller Y values go UP towards the top of the screen.
        let y = cy - ry * CGFloat(cos(thetaRadians))

        return OpponentPlacement(x: x, y: y, rotation: thetaDegrees)
    }

    @ViewBuilder
    private func staticOpponentHand(cards: [Card]) -> some View {
        let cardW: CGFloat = (cards.count >= 10 ? 98 : 101.5) * handScale
        let cardH: CGFloat = (cards.count >= 10 ? 140 : 145) * handScale
        let sp: CGFloat = (cards.count >= 10 ? -72 : -66) * handScale
        let center = Double(cards.count - 1) / 2.0
        let fan: Double = 4
        let yMult = 5.0 * Double(handScale)

        HStack(spacing: sp) {
            ForEach(cards) { card in
                let idx = cards.firstIndex(of: card)!
                let angle = Angle.degrees((Double(idx) - center) * -fan)
                let yOff = -abs((Double(idx) - center) * yMult)
                let reveal: Double = (game.playerHasWon || game.opponentHasWon) ? 360 : 180

                CardView(frontImage: card.imageName, cardHeight: cardH, rotation: reveal)
                    .rotationEffect(angle)
                    .offset(y: yOff)
                    .shadow(color: .black.opacity(0.25), radius: 20)
                    .animation(
                        .spring(response: 0.6, dampingFraction: 0.7).delay(Double(idx) * 0.1),
                        value: game.playerHasWon || game.opponentHasWon
                    )
            }
            .frame(width: cardW, height: cardH)
        }
        .frame(height: cardH)
    }
}
