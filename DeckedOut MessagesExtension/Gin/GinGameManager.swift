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
    @Published var phase: TurnPhase = .drawPhase
    @Published var playerHasWon: Bool = false
    @Published var opponentHasWon: Bool = false
    
    init() {
        self.playerHand = []
        self.opponentHand = []
        self.deck = []
        self.discardPile = []
        self.phase = .drawPhase
        self.playerHasWon = false
        self.opponentHasWon = false
    }
    
    
    // The View Controller will listen to this to know when to send the message
    var onTurnCompleted: ((GameState) -> Void)?
    
    enum TurnPhase {
        case drawPhase    // Waiting for user to pick from Deck or Discard
        case discardPhase // Waiting for user to drag a card to discard pile
        case idlePhase    // Opponent's turn
        case gameEndPhase // Only unlocked upon winning
    }
    
    
    
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
              //playerHand.count == 11, //cards can also equal 8 with games of hand size 7
              let index = playerHand.firstIndex(of: card) else { return }
        
        playerHand.remove(at: index)
        discardPile.insert(card, at: 0)
        SoundManager.instance.playCardSlap()
        self.playerHasWon = GinRummyValidator.canMeldAllCards(hand: self.playerHand)
        if self.playerHasWon {
            SoundManager.instance.playGameWin(didWin: true)
            phase = .gameEndPhase
            SoundManager.instance.playGameWin(didWin: true)
        } else { phase = .idlePhase }
        sendGameState()
    }
    
    func sendGameState() {
        let currentGameState = GameState(
            deck: self.deck,
            discardPile: self.discardPile,
            senderHand: self.playerHand,
            receiverHand: self.opponentHand
        )
        
        print(currentGameState)
        
        onTurnCompleted?(currentGameState) //send data to MessagesViewController
    }
    
    func loadState(_ state: GameState, isPlayersTurn: Bool) { //didRecieve, didSelect triggers upon sending as well, triggering loadState. in a perfect world, this would only trigger upon *recieving* a move from the opponent, but that can be changed later. Right now it triggers both times so there is slight repetition
        //print("loading state")
        self.deck = state.deck
        self.discardPile = state.discardPile
        
        self.playerHand = isPlayersTurn ? state.receiverHand : state.senderHand
        self.opponentHand = isPlayersTurn ? state.senderHand : state.receiverHand
        
        checkWin()
        
        if self.playerHasWon || self.opponentHasWon {
            self.phase = .gameEndPhase
            SoundManager.instance.playGameWin(didWin: self.playerHasWon)
        } else {
            self.phase = isPlayersTurn ? .drawPhase : .idlePhase
        }

    }
    
    func createNewGameState(withHandSize: Int) -> GameState {
        var newDeck = Deck().cards
        var newPlayerHand: [Card] = []
        var newOpponentHand: [Card] = []
        for _ in 0..<withHandSize {
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
    
    func checkWin() {
        self.playerHasWon = GinRummyValidator.canMeldAllCards(hand: self.playerHand)
        self.opponentHasWon = GinRummyValidator.canMeldAllCards(hand: self.opponentHand)
    }
    
}
