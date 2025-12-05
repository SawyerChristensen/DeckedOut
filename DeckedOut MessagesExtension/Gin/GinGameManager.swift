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
    
    init() {
        
        self.playerHand = []
        self.opponentHand = []
        self.deck = []
        self.discardPile = []
        self.phase = .drawPhase
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
        //print("loadState")
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
    
    func currentPlayerWon() -> Bool {
        return GinRummyValidator.canMeldAllTen(hand: self.playerHand)}
    
    func opponentWon() -> Bool { //currently unused, but if true should flip the opponents hand, display their cards, and give them a yellow glow in gingameview
        return GinRummyValidator.canMeldAllTen(hand: self.opponentHand)}
}
