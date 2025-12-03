//
//  GinGameManager.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 11/26/25.
//

import Foundation

// The game snapshot for sending the game over iMessage
struct GameState: Codable {
    let deck: [Card]
    let discardPile: [Card]
    let senderHand: [Card]
    let receiverHand: [Card]
}

// MARK: The Game Engine
class GameManager: ObservableObject {
    @Published var playerHand: [Card]
    @Published var opponentHand: [Card]
    @Published var deck: [Card]
    @Published var discardPile: [Card]
    
    init() { // THESE SHOULD BE SENT TO EMPTY AFTER THE CREATE GAME FUNCTION IS WRITTEN
        
        self.playerHand = []
        self.opponentHand = []
        self.deck = []
        self.discardPile = []
        /*
        self.deck = Deck().cards
        
        for card in 0..<9 {
            self.playerHand.append(deck.removeFirst()) //see if removefirst, remove last is faster
        }
        print(self.playerHand.count)
        
        for card in 0..<9 {
            self.opponentHand.append(deck.removeFirst()) //see if removefirst, remove last is faster
        }
        
        self.discardPile.append(deck.removeFirst())*/
        
        /*self.playerHand = [.init(suit: .clubs, rank: .ace),
                           .init(suit: .clubs, rank: .two),
                           .init(suit: .clubs, rank: .three),
                           
                           .init(suit: .clubs, rank: .four),
                           .init(suit: .clubs, rank: .five),
                           .init(suit: .clubs, rank: .six),
                           .init(suit: .clubs, rank: .seven),
                           .init(suit: .clubs, rank: .eight),
                           .init(suit: .clubs, rank: .nine),
                           .init(suit: .clubs, rank: .ten)]
        self.opponentHand = [.init(suit: .diamonds, rank: .five),
                             .init(suit: .diamonds, rank: .six),
                             .init(suit: .diamonds, rank: .seven),
                             
                             .init(suit: .diamonds, rank: .seven),
                             .init(suit: .diamonds, rank: .seven),
                             .init(suit: .diamonds, rank: .seven),

                             .init(suit: .diamonds, rank: .eight),
                             .init(suit: .diamonds, rank: .nine),
                             .init(suit: .diamonds, rank: .ten),
                             .init(suit: .diamonds, rank: .jack)]
        self.discardPile = [.init(suit: .hearts, rank: .ace),
                            .init(suit: .hearts, rank: .two),
                            .init(suit: .hearts, rank: .three),
                            .init(suit: .hearts, rank: .four)]
        self.deck = [.init(suit: .spades, rank: .five),
                     .init(suit: .spades, rank: .six),
                     .init(suit: .spades, rank: .seven),
                     
                     .init(suit: .spades, rank: .seven),
                     .init(suit: .spades, rank: .seven),
                     .init(suit: .spades, rank: .seven),

                     .init(suit: .spades, rank: .eight),
                     .init(suit: .spades, rank: .nine),
                     .init(suit: .spades, rank: .ten)]*/
        self.phase = .drawPhase
        
        //setupDemoData()
        }
    
    // The View Controller will listen to this to know when to send the message
    var onTurnCompleted: ((GameState) -> Void)?
    
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
        sendGameState()
    }
    
    func sendGameState() {
        let currentGameState = GameState(
            deck: self.deck,
            discardPile: self.discardPile,
            senderHand: self.playerHand,
            receiverHand: self.opponentHand
        )
        
        onTurnCompleted?(currentGameState) //send data to MessagesViewController
    }
    
    func loadState(_ state: GameState) {
        self.deck = state.deck
        self.discardPile = state.discardPile
        
        // The person who sent this message put their cards in "senderHand".
        // To the receiver, those are the opponent's cards.
        self.opponentHand = state.senderHand
        
        // The person who sent this message put the user's cards in "recieverHand".
        self.playerHand = state.receiverHand
        
        // Start the current user's turn phase
        self.phase = .drawPhase
    }
    
    func createNewGameState() -> GameState {
        var newDeck = Deck().cards
        var newPlayerHand: [Card] = []
        var newOpponentHand: [Card] = []
        for _ in 0..<10 {
            newPlayerHand.append(newDeck.popLast()!) //see if removefirst, remove last is faster
            newOpponentHand.append(newDeck.popLast()!)
        }
        var newDiscardPile: [Card] = []
        newDiscardPile.append(newDeck.removeFirst())
        
        let currentGameState = GameState(
            deck: newDeck,
            discardPile: newDiscardPile,
            senderHand: newPlayerHand,
            receiverHand: newOpponentHand)
        
        return currentGameState
    }
}
