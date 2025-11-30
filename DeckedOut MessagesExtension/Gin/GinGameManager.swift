//
//  GinGameManager.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 11/26/25.
//

import Foundation

class GameManager: ObservableObject {
    @Published var playerHand: [Card] = [.init(suit: .clubs, rank: .ace),
                                         .init(suit: .clubs, rank: .two),
                                         .init(suit: .clubs, rank: .three),
                                         
                                         .init(suit: .clubs, rank: .four),
                                         .init(suit: .clubs, rank: .five),
                                         .init(suit: .clubs, rank: .six),

                                         .init(suit: .clubs, rank: .seven),
                                         .init(suit: .clubs, rank: .eight),
                                         .init(suit: .clubs, rank: .nine),
                                         .init(suit: .clubs, rank: .ten)]
    
    @Published var opponentHand: [Card] = [.init(suit: .hearts, rank: .five),
                                           .init(suit: .hearts, rank: .six),
                                           .init(suit: .hearts, rank: .seven),
                                           
                                           .init(suit: .spades, rank: .seven),
                                           .init(suit: .diamonds, rank: .seven),
                                           .init(suit: .clubs, rank: .seven),

                                           .init(suit: .clubs, rank: .eight),
                                           .init(suit: .clubs, rank: .nine),
                                           .init(suit: .clubs, rank: .ten),
                                           .init(suit: .clubs, rank: .jack)]
        
    @Published var discardPile: [Card] = [.init(suit: .hearts, rank: .ace),
                                          .init(suit: .hearts, rank: .two),
                                          .init(suit: .hearts, rank: .three),
                                          .init(suit: .hearts, rank: .four)]
    
    @Published var deck: [Card] = [.init(suit: .spades, rank: .five),
                                   .init(suit: .spades, rank: .six),
                                   .init(suit: .spades, rank: .seven),
                                   
                                   .init(suit: .spades, rank: .seven),
                                   .init(suit: .spades, rank: .seven),
                                   .init(suit: .spades, rank: .seven),

                                   .init(suit: .spades, rank: .eight),
                                   .init(suit: .spades, rank: .nine),
                                   .init(suit: .spades, rank: .ten)]
    
    // Optional drag state shared across views:
    //@Published var draggedCard: Card? = nil
    
    func drawFromDiscard() {
        guard !discardPile.isEmpty else { return } //this should never trigger
        let card = discardPile.removeFirst()
        playerHand.append(card)
    }
    
    func drawFromDeck() {
        guard !deck.isEmpty else { return } //this should also never trigger
        let card = deck.removeFirst()
        playerHand.append(card)
    }
}
