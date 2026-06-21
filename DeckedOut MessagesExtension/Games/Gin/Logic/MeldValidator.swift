//
//  GinRummy.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 11/17/25.
//

import Foundation

struct GinKnockOutcome {
    let knockerDeadwood: Int
    let defenderDeadwoodBeforeLayoff: Int
    let defenderDeadwoodAfterLayoff: Int

    var isUndercut: Bool {
        defenderDeadwoodAfterLayoff <= knockerDeadwood
    }
}

private struct GinMeldLayout {
    let melds: [[Card]]
    let deadwoodCards: [Card]
    let deadwoodPoints: Int
}

private struct ActiveMeld {
    enum Kind {
        case set
        case run
    }

    var kind: Kind
    var cards: [Card]
}

/**
 A Gin Rummy hand validator.
 
 This class provides a static function to determine if a card hand
 is a "Gin" hand, meaning all cards can be perfectly
 arranged into melds (sets and runs) with no deadwood.
 */
public class GinRummyValidator {

    private static let numSuits = 4
    private static let numRanks = 13

    /**
     Checks if a given card hand can be fully melded (a "Gin" hand).
     
     - Parameter cards: An array of `Card` objects.
     - Returns: `true` if all cards can be arranged into valid melds,
       `false` otherwise.
     */
    static func canMeldAllCards(hand: [Card]) -> Bool {
        // --- 1. Convert the [Card] array to our 2D grid representation ---
        // This makes lookups (e.g., "do we have the 7 of Spades?") instantaneous.
        // `handGrid[suit][rank]` will be 1 if we have the card, 0 otherwise.
        var handGrid = Array(repeating: Array(repeating: 0, count: numRanks), count: numSuits)
        for card in hand {
            handGrid[card.suit.rawValue][card.rank.rawValue] = 1
        }
        
        // --- 2. Start the recursive search ---
        // We pass the grid (which will be modified) and the number
        // of cards we still need to meld.
        return canMeldRecursive(cardsToMeld: hand.count, handGrid: &handGrid) //hand.count should either be 7 or 10
    }

    /// Returns `true` when every card in the hand belongs to one continuous run of the same suit
    /// (e.g. 4♥–5♥–6♥–7♥–8♥–9♥–10♥). This is the rarest possible Gin — the whole hand is a single meld.
    static func isSingleRun(hand: [Card]) -> Bool {
        guard hand.count >= 3 else { return false }
        guard Set(hand.map { $0.suit.rawValue }).count == 1 else { return false }
        let ranks = hand.map { $0.rank.rawValue }.sorted()
        return zip(ranks, ranks.dropFirst()).allSatisfy { $0 + 1 == $1 }
    }

    /// Returns the smallest possible deadwood total after optimally partitioning the hand into melds.
    static func minimumDeadwoodPoints(hand: [Card]) -> Int {
        bestMeldLayout(hand: hand).deadwoodPoints
    }

    /// Evaluates a knock from the opener's post-discard hand against the defender's hand.
    /// Returns nil when the opener has more than 10 deadwood and therefore cannot legally knock.
    static func evaluateKnock(knockerHand: [Card], defenderHand: [Card]) -> GinKnockOutcome? {
        let knockerLayouts = allMeldLayouts(hand: knockerHand)
        let minimumKnockerDeadwood = knockerLayouts.map(\.deadwoodPoints).min() ?? Int.max
        guard minimumKnockerDeadwood <= 10 else { return nil }

        let optimalKnockerLayouts = knockerLayouts.filter { $0.deadwoodPoints == minimumKnockerDeadwood }
        let defenderLayouts = allMeldLayouts(hand: defenderHand)

        var chosenOutcome: GinKnockOutcome?

        for knockerLayout in optimalKnockerLayouts {
            // Defender picks the layout that gives them the least deadwood after layoff.
            var defenderBestAfterLayoff = Int.max
            var defenderDeadwoodBeforeLayoff = Int.max

            for defenderLayout in defenderLayouts {
                let defenderAfterLayoff = deadwoodAfterBestLayoff(
                    deadwoodCards: defenderLayout.deadwoodCards,
                    ontoMelds: knockerLayout.melds
                )

                if defenderAfterLayoff < defenderBestAfterLayoff {
                    defenderBestAfterLayoff = defenderAfterLayoff
                    defenderDeadwoodBeforeLayoff = defenderLayout.deadwoodPoints
                }
            }

            let candidate = GinKnockOutcome(
                knockerDeadwood: knockerLayout.deadwoodPoints,
                defenderDeadwoodBeforeLayoff: defenderDeadwoodBeforeLayoff,
                defenderDeadwoodAfterLayoff: defenderBestAfterLayoff
            )

            // If the knocker has multiple equivalent deadwood layouts, pick the one that
            // minimizes defender layoff (best for the knocker).
            if let existing = chosenOutcome {
                if candidate.defenderDeadwoodAfterLayoff > existing.defenderDeadwoodAfterLayoff {
                    chosenOutcome = candidate
                }
            } else {
                chosenOutcome = candidate
            }
        }

        return chosenOutcome
    }

    private static func bestMeldLayout(hand: [Card]) -> GinMeldLayout {
        let layouts = allMeldLayouts(hand: hand)
        return layouts.min {
            if $0.deadwoodPoints != $1.deadwoodPoints {
                return $0.deadwoodPoints < $1.deadwoodPoints
            }
            let lhs = $0.deadwoodCards.map(\.id).sorted()
            let rhs = $1.deadwoodCards.map(\.id).sorted()
            return lhs.lexicographicallyPrecedes(rhs)
        } ?? GinMeldLayout(melds: [], deadwoodCards: hand, deadwoodPoints: deadwoodPoints(for: hand))
    }

    private static func allMeldLayouts(hand: [Card]) -> [GinMeldLayout] {
        var layouts: [GinMeldLayout] = []
        let sortedHand = hand.sorted { $0.id < $1.id }

        func recurse(remaining: [Card], melds: [[Card]], deadwood: [Card]) {
            guard let anchor = remaining.first else {
                let sortedDeadwood = deadwood.sorted { $0.id < $1.id }
                layouts.append(
                    GinMeldLayout(
                        melds: melds,
                        deadwoodCards: sortedDeadwood,
                        deadwoodPoints: deadwoodPoints(for: sortedDeadwood)
                    )
                )
                return
            }

            // Option 1: treat anchor card as deadwood.
            recurse(
                remaining: Array(remaining.dropFirst()),
                melds: melds,
                deadwood: deadwood + [anchor]
            )

            // Option 2: place anchor into each possible meld that contains it.
            for meld in meldCandidates(containing: anchor, in: remaining) {
                let remainingAfterMeld = removing(cards: meld, from: remaining)
                recurse(remaining: remainingAfterMeld, melds: melds + [meld], deadwood: deadwood)
            }
        }

        recurse(remaining: sortedHand, melds: [], deadwood: [])
        return layouts
    }

    private static func meldCandidates(containing anchor: Card, in cards: [Card]) -> [[Card]] {
        var candidates: [[[Card]]] = []

        // Candidate sets (same rank, 3-4 cards)
        let sameRank = cards.filter { $0.rank == anchor.rank }.sorted { $0.id < $1.id }
        if sameRank.count == 3 {
            candidates.append([sameRank])
        } else if sameRank.count == 4 {
            var setCandidates: [[Card]] = [sameRank]
            for i in 0..<4 {
                var threeCardSet = sameRank
                threeCardSet.remove(at: i)
                setCandidates.append(threeCardSet)
            }
            candidates.append(setCandidates)
        }

        // Candidate runs (same suit, 3+ consecutive, must include anchor)
        let suitedCards = cards.filter { $0.suit == anchor.suit }
        var rankToCard: [Int: Card] = [:]
        suitedCards.forEach { rankToCard[$0.rank.rawValue] = $0 }
        var runCandidates: [[Card]] = []

        for start in 0..<(numRanks - 2) {
            for end in (start + 2)..<numRanks {
                guard anchor.rank.rawValue >= start, anchor.rank.rawValue <= end else { continue }

                var run: [Card] = []
                var isValidRun = true
                for rank in start...end {
                    guard let card = rankToCard[rank] else {
                        isValidRun = false
                        break
                    }
                    run.append(card)
                }

                if isValidRun {
                    runCandidates.append(run)
                }
            }
        }

        if !runCandidates.isEmpty {
            candidates.append(runCandidates)
        }

        // Flatten and de-duplicate by card id signature.
        var seenSignatures = Set<String>()
        var uniqueCandidates: [[Card]] = []
        for meld in candidates.flatMap({ $0 }) {
            let signature = meld.map(\.id).sorted().map(String.init).joined(separator: "-")
            if seenSignatures.insert(signature).inserted {
                uniqueCandidates.append(meld.sorted { $0.id < $1.id })
            }
        }

        return uniqueCandidates
    }

    private static func removing(cards cardsToRemove: [Card], from source: [Card]) -> [Card] {
        var remaining = source
        for card in cardsToRemove {
            if let index = remaining.firstIndex(of: card) {
                remaining.remove(at: index)
            }
        }
        return remaining
    }

    private static func deadwoodAfterBestLayoff(deadwoodCards: [Card], ontoMelds melds: [[Card]]) -> Int {
        let activeMelds: [ActiveMeld] = melds.map { meld in
            let isSet = Set(meld.map(\.rank)).count == 1
            return ActiveMeld(kind: isSet ? .set : .run, cards: meld.sorted { $0.rank.rawValue < $1.rank.rawValue })
        }

        let orderedDeadwood = deadwoodCards.sorted {
            let lhs = deadwoodPointValue(for: $0)
            let rhs = deadwoodPointValue(for: $1)
            if lhs != rhs { return lhs > rhs }
            return $0.id < $1.id
        }

        func recurse(index: Int, melds: [ActiveMeld], currentDeadwood: Int) -> Int {
            guard index < orderedDeadwood.count else { return currentDeadwood }

            let card = orderedDeadwood[index]
            let cardPoints = deadwoodPointValue(for: card)

            // Option 1: do not lay this card off.
            var best = recurse(index: index + 1, melds: melds, currentDeadwood: currentDeadwood)

            // Option 2: lay this card off onto any compatible meld.
            for meldIndex in melds.indices {
                if let updatedMeld = laidOff(meld: melds[meldIndex], with: card) {
                    var nextMelds = melds
                    nextMelds[meldIndex] = updatedMeld
                    let laidOffDeadwood = recurse(
                        index: index + 1,
                        melds: nextMelds,
                        currentDeadwood: currentDeadwood - cardPoints
                    )
                    if laidOffDeadwood < best {
                        best = laidOffDeadwood
                    }
                }
            }

            return best
        }

        return recurse(index: 0, melds: activeMelds, currentDeadwood: deadwoodPoints(for: deadwoodCards))
    }

    private static func laidOff(meld: ActiveMeld, with card: Card) -> ActiveMeld? {
        switch meld.kind {
        case .set:
            guard let first = meld.cards.first else { return nil }
            guard card.rank == first.rank else { return nil }
            guard meld.cards.count < 4 else { return nil }
            guard !meld.cards.contains(where: { $0.suit == card.suit }) else { return nil }

            var updated = meld.cards
            updated.append(card)
            return ActiveMeld(kind: .set, cards: updated.sorted { $0.id < $1.id })

        case .run:
            guard let first = meld.cards.first, let last = meld.cards.last else { return nil }
            guard card.suit == first.suit else { return nil }

            let rank = card.rank.rawValue
            if rank == first.rank.rawValue - 1 {
                var updated = meld.cards
                updated.insert(card, at: 0)
                return ActiveMeld(kind: .run, cards: updated)
            }
            if rank == last.rank.rawValue + 1 {
                var updated = meld.cards
                updated.append(card)
                return ActiveMeld(kind: .run, cards: updated)
            }
            return nil
        }
    }

    private static func deadwoodPoints(for cards: [Card]) -> Int {
        cards.reduce(0) { $0 + deadwoodPointValue(for: $1) }
    }

    private static func deadwoodPointValue(for card: Card) -> Int {
        switch card.rank {
        case .ace:
            return 1
        case .jack, .queen, .king:
            return 10
        default:
            return card.rank.rawValue + 1
        }
    }

    /**
     The private recursive (backtracking) function that solves the puzzle.
     
     It tries to find one valid partition of the cards into melds.
     
     - Parameter cardsToMeld: The number of cards remaining to be melded.
     - Parameter handGrid: A 2D array representing the cards still in the hand.
     - Returns: `true` if a valid "all melded" solution is found, `false` otherwise.
     */
    private static func canMeldRecursive(cardsToMeld: Int, handGrid: inout [[Int]]) -> Bool {
        
        // --- BASE CASE ---
        // If we have 0 cards left to meld, we have successfully melded all cards. This is a "Gin" hand!
        if cardsToMeld == 0 {
            return true
        }

        // --- FIND ANCHOR CARD ---
        // Find the first card in the hand that we need to find a meld for.
        var anchorR = -1 // suit
        var anchorC = -1 // rank
        
        find_first_card:
        for r in 0..<numSuits {
            for c in 0..<numRanks {
                if handGrid[r][c] == 1 {
                    anchorR = r
                    anchorC = c
                    break find_first_card
                }
            }
        }
        
        // If we still have cardsToMeld, but no card was found, something is wrong.
        // This case should not be hit if cardsToMeld > 0.
        if anchorR == -1 {
            return false
        }
        
        // --- RECURSIVE STEP ---
        // We found our anchor card at (anchorR, anchorC).
        // Now, we must try to meld this card in every possible way.
        
        // --- Possibility 1: Try forming a RUN with this card ---
        // We check for runs of 3 or more that *contain* our anchor card.
        // e.g., if our card is 5♥, we must check for:
        // - 3♥, 4♥, 5♥
        // - 4♥, 5♥, 6♥
        // - 5♥, 6♥, 7♥
        // - 3♥, 4♥, 5♥, 6♥
        // - 4♥, 5♥, 6♥, 7♥
        // - 5♥, 6♥, 7♥, 8♥ ... and so on.

        // `c` is the *start* of the run
        for c in 0..<(numRanks - 2) {
            // `runLength`
            for len in 3...(numRanks - c) {
                // Check if this run is valid and *contains* our anchor card
                let runStart = c
                let runEnd = c + len - 1
                
                if anchorC >= runStart && anchorC <= runEnd {
                    // Our anchor card is in this run's range.
                    // Now, check if we *have* all the cards for this run.
                    var hasAllCards = true
                    var runCoords: [[Int]] = []
                    
                    for j in runStart...runEnd {
                        if handGrid[anchorR][j] == 1 {
                            runCoords.append([anchorR, j])
                        } else {
                            hasAllCards = false
                            break
                        }
                    }
                    
                    if hasAllCards {
                        // --- 1a. Try this meld ---
                        
                        // "Remove" cards from hand
                        for coord in runCoords { handGrid[coord[0]][coord[1]] = 0 }

                        // Recurse: if this path leads to a solution, we're done!
                        if canMeldRecursive(cardsToMeld: cardsToMeld - len, handGrid: &handGrid) {
                            return true
                        }
                        
                        // "Put back" cards (BACKTRACK)
                        for coord in runCoords { handGrid[coord[0]][coord[1]] = 1 }
                    }
                }
            }
        }
        
        // --- Possibility 2: Try forming a SET with this card ---
        // Find all cards of the same rank (anchorC)
        var suitsInSet: [Int] = []
        for r in 0..<numSuits {
            if handGrid[r][anchorC] == 1 {
                suitsInSet.append(r)
            }
        }

        if suitsInSet.count >= 3 {
            // We have a 3-card or 4-card set.
            // Note: Our anchor card (anchorR) is guaranteed to be in suitsInSet.
            
            // --- 2a. Try a 3-card set ---
            // We must find all 3-card combinations.
            // If we have 4 cards {S, H, D, C}, we can make 4 different 3-card sets:
            // {S, H, D}, {S, H, C}, {S, D, C}, {H, D, C}
            
            // This is a "combinations" problem.
            if suitsInSet.count == 3 {
                // Only one 3-card set possible.
                let coords = [
                    [suitsInSet[0], anchorC],
                    [suitsInSet[1], anchorC],
                    [suitsInSet[2], anchorC]
                ]
                
                for coord in coords { handGrid[coord[0]][coord[1]] = 0 }
                if canMeldRecursive(cardsToMeld: cardsToMeld - 3, handGrid: &handGrid) {
                    return true
                }
                for coord in coords { handGrid[coord[0]][coord[1]] = 1 } // Backtrack
                
            } else if suitsInSet.count == 4 {
                // Four 3-card combinations are possible.
                for i in 0..<4 { // 'i' is the suit to *exclude*
                    var coords: [[Int]] = []
                    for j in 0..<4 {
                        if i == j { continue } // Skip the excluded suit
                        coords.append([suitsInSet[j], anchorC])
                    }
                    
                    for coord in coords { handGrid[coord[0]][coord[1]] = 0 }
                    if canMeldRecursive(cardsToMeld: cardsToMeld - 3, handGrid: &handGrid) {
                        return true
                    }
                    for coord in coords { handGrid[coord[0]][coord[1]] = 1 } // Backtrack
                }
                
                // --- 2b. Try a 4-card set ---
                // Only one 4-card set possible.
                let coords = [
                    [suitsInSet[0], anchorC],
                    [suitsInSet[1], anchorC],
                    [suitsInSet[2], anchorC],
                    [suitsInSet[3], anchorC]
                ]
                
                for coord in coords { handGrid[coord[0]][coord[1]] = 0 }
                if canMeldRecursive(cardsToMeld: cardsToMeld - 4, handGrid: &handGrid) {
                    return true
                }
                for coord in coords { handGrid[coord[0]][coord[1]] = 1 } // Backtrack
            }
        }
        
        // --- No Solution Found ---
        // If we tried all possible runs and sets for our anchor card and none of them led to a full solution, then this hand is not a "Gin" hand.
        return false
    }
}
