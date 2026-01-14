//
//  GinRummy.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 11/17/25.
//

import Foundation

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
