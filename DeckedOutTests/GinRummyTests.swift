//
//  GinRummyTests.swift
//  DeckedOutTests
//
//  Created by Sawyer Christensen on 11/17/25.
//

import Testing
/*
@testable import DeckedOut_MessagesExtension

struct GinRummyTests {

    // Example 1: A perfect Gin hand (10 cards)
    @Test("Perfect 10-Card Gin Hand")
    func testPerfectGinHand() async throws {
        // Arrange
        // Meld 1: 5♥, 6♥, 7♥ (Run)
        // Meld 2: 7♠, 7♦, 7♣ (Set)
        // Meld 3: 8♣, 9♣, 10♣, J♣ (Run)
        let ginHand: [Card] = [
            .init(suit: .hearts, rank: .five),
            .init(suit: .hearts, rank: .six),
            .init(suit: .hearts, rank: .seven),
            
            .init(suit: .spades, rank: .seven),
            .init(suit: .diamonds, rank: .seven),
            .init(suit: .clubs, rank: .seven),

            .init(suit: .clubs, rank: .eight),
            .init(suit: .clubs, rank: .nine),
            .init(suit: .clubs, rank: .ten),
            .init(suit: .clubs, rank: .jack)
        ]
        
        // Act
        print("--- Testing Hand 1 (Perfect Gin) ---") // Your print() still works here
        let isGin = GinRummyValidator.canMeldAllTen(hand: ginHand)

        // Assert
        // This line will automatically pass or fail the test.
        #expect(isGin == true, "A perfect 10-card meld should return true")
    }

    // Example 2: A hand with 1 deadwood card
    @Test("Hand with 1 Deadwood Card")
    func testHandWithDeadwood() async throws {
        // Arrange
        let notGinHand: [Card] = [
            .init(suit: .hearts, rank: .five),
            .init(suit: .hearts, rank: .six),
            .init(suit: .hearts, rank: .seven),
            
            .init(suit: .spades, rank: .seven),
            .init(suit: .diamonds, rank: .seven),
            .init(suit: .clubs, rank: .seven),

            .init(suit: .clubs, rank: .eight),
            .init(suit: .clubs, rank: .nine),
            .init(suit: .clubs, rank: .ten),
            .init(suit: .diamonds, rank: .jack) // The deadwood card
        ]

        // Act
        print("--- Testing Hand 2 (Has Deadwood) ---")
        let isGin = GinRummyValidator.canMeldAllTen(hand: notGinHand)

        // Assert
        #expect(isGin == false, "A hand with deadwood should return false")
    }
    
    // Example 3: A 10-card hand with 1 deadwood
    @Test("Hand with 3 Sets and 1 Deadwood")
    func testThreeSetsAndDeadwood() async throws {
        // Arrange
        // {5♥, 6♥, 7♥}
        // {5♠, 6♠, 7♠}
        // {5♦, 6♦, 7♦}
        // {5♣} <-- Deadwood
        let hand3: [Card] = [
            .init(suit: .hearts, rank: .five),
            .init(suit: .hearts, rank: .six),
            .init(suit: .hearts, rank: .seven),
            
            .init(suit: .spades, rank: .five),
            .init(suit: .spades, rank: .six),
            .init(suit: .spades, rank: .seven),
            
            .init(suit: .diamonds, rank: .five),
            .init(suit: .diamonds, rank: .six),
            .init(suit: .diamonds, rank: .seven),
            
            .init(suit: .clubs, rank: .three) // Deadwood (turn into 5, 6, or 7 to make it true!
        ]

        // Act
        print("--- Testing Hand 3 (Three Sets, 1 Deadwood) ---")
        let isGin = GinRummyValidator.canMeldAllTen(hand: hand3)
        
        // Assert
        #expect(isGin == false, "Hand 3 has a deadwood card and should return false")
    }
    
    // Example 4: A 10-card hand that could be melded incorrectly (overlap)
    @Test("Complex Overlapping Meld Hand (Gin)")
    func testComplexOverlap() async throws {
        // Arrange
        // Hand: {5♥, 6♥, 7♥, 8♥} + {7♠, 7♦, 7♣} + {8♣, 9♣, 10♣}
        // A greedy (sets-first) algorithm might fail.
        // The correct solution is a Gin.
        let complexHand: [Card] = [
            .init(suit: .hearts, rank: .five),
            .init(suit: .hearts, rank: .six),
            .init(suit: .hearts, rank: .seven),
            .init(suit: .hearts, rank: .eight),

            .init(suit: .spades, rank: .seven),
            .init(suit: .diamonds, rank: .seven),
            .init(suit: .clubs, rank: .seven),
            
            .init(suit: .clubs, rank: .eight),
            .init(suit: .clubs, rank: .nine),
            .init(suit: .clubs, rank: .ten)
        ]

        // Act
        print("--- Testing Hand 4 (Complex Overlap) ---")
        let isGin = GinRummyValidator.canMeldAllTen(hand: complexHand)
        
        // Assert
        #expect(isGin == true, "This complex hand is a valid Gin and should return true")
    }
}
*/
