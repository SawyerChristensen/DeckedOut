//
//  GinGameManager.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 11/26/25.
//

import Foundation

class GameManager: ObservableObject {
    @Published var playerHand: [Card] = [.init(suit: .hearts, rank: .five),
                                         .init(suit: .hearts, rank: .six),
                                         .init(suit: .hearts, rank: .seven),
                                         
                                         .init(suit: .spades, rank: .seven),
                                         .init(suit: .diamonds, rank: .seven),
                                         .init(suit: .clubs, rank: .seven),

                                         .init(suit: .clubs, rank: .eight),
                                         .init(suit: .clubs, rank: .nine),
                                         .init(suit: .clubs, rank: .ten),
                                         .init(suit: .clubs, rank: .jack)]
    
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
                                          .init(suit: .hearts, rank: .two)]
    
    @Published var deck: [Card] = [.init(suit: .hearts, rank: .five),
                                   .init(suit: .hearts, rank: .six),
                                   .init(suit: .hearts, rank: .seven),
                                   
                                   .init(suit: .spades, rank: .seven),
                                   .init(suit: .diamonds, rank: .seven),
                                   .init(suit: .clubs, rank: .seven),

                                   .init(suit: .clubs, rank: .eight),
                                   .init(suit: .clubs, rank: .nine),
                                   .init(suit: .clubs, rank: .ten)]
    
    // Optional drag state shared across views:
    @Published var draggedCard: Card? = nil
}
