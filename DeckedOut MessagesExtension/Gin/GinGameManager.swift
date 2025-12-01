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
    
    enum TurnPhase {
        case drawPhase    // Waiting for user to pick from Deck or Discard
        case discardPhase // Waiting for user to drag a card to discard pile
        case idlePhase    // Opponent's turn
    }
    
    @Published var phase: TurnPhase = .drawPhase
    
    func drawFromDeck() {
        guard phase == .drawPhase, !deck.isEmpty else { return }
        let card = deck.removeFirst()
        playerHand.append(card)
        phase = .discardPhase
    }
    
    func drawFromDiscard() {
        guard phase == .drawPhase, !discardPile.isEmpty else { return }
        let card = discardPile.removeFirst()
        playerHand.append(card)
        phase = .discardPhase
    }
    
    func discardCard(card: Card) {
        guard phase == .discardPhase,
            playerHand.count == 11,
            let index = playerHand.firstIndex(of: card) else { return }

        playerHand.remove(at: index)
        discardPile.insert(card, at: 0)
        phase = .idlePhase
    }

}
