//
//  GolfOpponentsSectionView.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 5/10/26.
//

import SwiftUI

struct GolfOpponentsSectionView: View {
    @EnvironmentObject var game: GolfManager

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

    private var handScale: CGFloat {
        switch opponentCount {
        case 0...4:
            return 0.5
        case 5...6:
            return 0.35
        default:
            return 0.2
        }
    }
    private var screenWidth: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? game.extensionWidth : UIScreen.main.bounds.width
    }
    // Vertical padding applied above AND below the horizontal row divider.
    // Negative values pull rows closer together. Tweak this to control row spacing for 5–6 opponents.
    private var rowDividerVerticalPadding: CGFloat {
        opponentCount > 4 ? -10 : 0
    }
    private var frameHeight: CGFloat {
        let cardH: CGFloat = 100 * handScale
        let spacingV: CGFloat = 12 * handScale
        let singleHandHeight = (cardH * 2) + spacingV + 60
        let rowCount = CGFloat((opponentCount + 1) / 2) //why plus 1?
        let verticalPadding: CGFloat = 30 + (15 * max(0, rowCount - 1))
        let dividerCount = max(0, rowCount - 1)
        // Each row divider contributes 2pt (its own height) + 2 × verticalPadding
        let dividerContribution: CGFloat = dividerCount * (2 + 2 * rowDividerVerticalPadding)

        return (singleHandHeight * rowCount) + verticalPadding + dividerContribution
    }

    // MARK: 1v1 view
    var body: some View {
        if game.isSinglePlayer || game.seats.count <= 2 {
            let opponentSeat = game.seats.indices.contains(game.mySeatIndex)
                ? (game.mySeatIndex + 1) % max(game.seats.count, 1)
                : 0
            GolfOpponentHandView(
                cards: game.opponentHand,
                faceUpIndices: game.opponentFaceUpIndices,
                discardPileZone: discardPileZone,
                deckZone: deckZone,
                cardBackName: game.isSinglePlayer ? game.opponentCardBack : game.cardBack(forSeat: opponentSeat)
            )
            .padding(.vertical, 30)

        } else {
            multiOpponentGrid
        }
    }

    @ViewBuilder
    private var multiOpponentGrid: some View {
        let seats = opponentSeats
        let rows = stride(from: 0, to: seats.count, by: 2).map {
            Array(seats[$0..<min($0 + 2, seats.count)])
        }
        
        VStack(spacing: 10) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, rowSeats in
                HStack(spacing: 0) {
                    // Left Opponent
                    handContainer(forIndex: rowIndex * 2, seatIndex: rowSeats[0])
                        .frame(maxWidth: .infinity)
                    
                    if rowSeats.count > 1 {
                        // Divider between columns
                        Divider()
                            .frame(width: 2)
                            .overlay(Color.white.opacity(0.3))
                            .padding(.vertical, 5)
                        
                        // Right Opponent
                        handContainer(forIndex: (rowIndex * 2) + 1, seatIndex: rowSeats[1])
                            .frame(maxWidth: .infinity)
                    } //else {
                        // Keep grid balanced if there is an odd number of opponents (fills empty right space)
                        //Color.clear
                            //.frame(maxWidth: .infinity)
                    //}
                }
                
                // Add horizontal divider between rows, unless it's the last row
                if rowIndex < rows.count - 1 {
                    Divider()
                        .frame(height: 2)
                        .overlay(Color.white.opacity(0.3))
                        .padding(.horizontal, 10)
                        //.padding(.vertical, 5)
                }
            }
        }
        .padding(.top, 10)
        .padding(.vertical, opponentCount > 4 ? 50 : 10)
        //.padding(.bottom, 5)
        .frame(width: screenWidth, height: frameHeight)
    }
    
    // MARK: Individual Hand Container
    @ViewBuilder
    private func handContainer(forIndex index: Int, seatIndex: Int) -> some View {
        let showAnimatedActive = (
            game.phase == .animationPhase ||
            game.isAnimatingOpponentTurn ||
            game.phase == .gameEndPhase && game.opponentHasWon)
        let isActive = showAnimatedActive && seatIndex == game.animatingOpponentSeat

        Group {
            if isActive {
                GolfOpponentHandView(
                    cards: game.opponentHand,
                    faceUpIndices: game.opponentFaceUpIndices,
                    discardPileZone: discardPileZone,
                    deckZone: deckZone,
                    sizeScale: handScale,
                    handRotation: 0, // grid layout never rotates the hand; mirrors arc-view API
                    cardBackName: game.cardBack(forSeat: seatIndex)
                )
            } else if seatIndex < game.allHands.count {
                staticOpponentHand(
                    cards: game.allHands[seatIndex],
                    faceUpIndices: game.allFaceUpIndices[seatIndex],
                    cardBackName: game.cardBack(forSeat: seatIndex)
                )
            }
        }
        .zIndex(isActive ? 1 : 0)
    }

    // MARK: Static Opponent Hand (2x3 Grid)
    @ViewBuilder
    private func staticOpponentHand(cards: [Card], faceUpIndices: Set<Int>, cardBackName: String = "cardBackRed") -> some View {
        let cardW: CGFloat = 91 * handScale
        let cardH: CGFloat = 130 * handScale
        let spacingH: CGFloat = 24 * handScale
        let spacingV: CGFloat = 12 * handScale
        let revealAll = game.isGameOver

        var cancelledSet: Set<Int> {
            guard cards.count == 6 else { return [] }
            var result: Set<Int> = []
            for (top, bottom) in [(0, 3), (1, 4), (2, 5)] {
                if faceUpIndices.contains(top) && faceUpIndices.contains(bottom) && cards[top].rank == cards[bottom].rank {
                    result.insert(top)
                    result.insert(bottom)
                }
            }
            return result
        }

        VStack(spacing: spacingV) {
            ForEach(0..<2, id: \.self) { row in
                HStack(spacing: spacingH) {
                    ForEach(0..<3, id: \.self) { col in
                        let index = row * 3 + col
                        if index < cards.count {
                            let isFaceUp = faceUpIndices.contains(index)
                            // Base rotation for individual cards if needed, container handles the 90/-90 macro rotation
                            let cardFlip: Double = (revealAll || isFaceUp) ? 0 : -180
                            let isCancelled = cancelledSet.contains(index)

                            CardView(frontImage: cards[index].imageName, backImageName: cardBackName, cardHeight: cardH, rotation: cardFlip)
                                .frame(width: cardW, height: cardH)
                                .opacity(isCancelled ? 0.8 : 1.0)
                                .shadow(color: .black.opacity(0.25), radius: 4)
                                .animation(
                                    .spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.1),
                                    value: revealAll
                                )
                        }
                    }
                }
            }
        }
        .frame(width: cardW * 3 + spacingH * 2, height: cardH * 2 + spacingV)
    }
}
