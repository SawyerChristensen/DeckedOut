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
    let senderDrewFromDeck: Bool
    let indexSenderDrewTo: Int?
    let indexSenderDiscardedFrom: Int?
}

// MARK: The Game Engine
class GameManager: ObservableObject {
    @Published var playerHand: [Card] = []
    @Published var opponentHand: [Card] = []
    @Published var deck: [Card] = []
    @Published var discardPile: [Card] = []
    @Published var phase: TurnPhase = .animationPhase
    @Published var opponentDrewFromDeck: Bool = false
    @Published var indexDrawnTo: Int? = nil
    @Published var indexDiscardedFrom: Int? = nil
    @Published var playerHasWon: Bool = false
    @Published var opponentHasWon: Bool = false
    
    init() {} // values are already initialized here ^
    
    // The View Controller will listen to this to know when to send the message
    var onTurnCompleted: ((GameState) -> Void)?
    
    enum TurnPhase {
        case animationPhase // Animating the opponents turn before your own
        case drawPhase    // Waiting for user to pick from Deck or Discard
        case discardPhase // Waiting for user to drag a card to discard pile
        case idlePhase    // Opponent's turn
        case gameEndPhase // Only unlocked upon winning
    }
    
    
    func drawFromDeck() {
        guard phase == .drawPhase, !deck.isEmpty else { return }
        let card = deck.popLast()! //maybe make this a guard statement? this does the samething in the earlier guard statement...
        playerHand.append(card)
        indexDrawnTo = playerHand.count - 1 //check if we need this to be -1!!
        opponentDrewFromDeck = true
        phase = .discardPhase
    }
    
    func drawFromDiscard() {
        guard phase == .drawPhase, !discardPile.isEmpty else { return }
        let card = discardPile.popLast()!
        playerHand.append(card)
        indexDrawnTo = playerHand.count - 1
        opponentDrewFromDeck = false
        phase = .discardPhase
    }
    
    func discardCard(card: Card) { //possible room for refactoring/removing discardCard
        guard phase == .discardPhase, let index = playerHand.firstIndex(of: card) else { return }
        indexDiscardedFrom = index
        playerHand.remove(at: index) //we could also use indexDiscardedFrom...
        discardPile.append(card)
        SoundManager.instance.playCardSlap()
        self.playerHasWon = GinRummyValidator.canMeldAllCards(hand: self.playerHand)
        if self.playerHasWon {
            SoundManager.instance.playGameWin(didWin: true)
            phase = .gameEndPhase
        } else { phase = .idlePhase }
        sendGameState()
    }
    
    func opponentDrawFromDeck() {
        guard phase == .animationPhase,
              !deck.isEmpty,
              let drawIndex = indexDrawnTo else {
            return
        }
        let card = deck.popLast()!
        self.opponentHand.insert(card, at: drawIndex)
    }
    
    func opponentDrawFromDiscard() {
        guard phase == .animationPhase,
              !discardPile.isEmpty,
              let drawIndex = indexDrawnTo else {
            return
        }
        let card = discardPile.popLast()!
        self.opponentHand.insert(card, at: drawIndex)
    }
    
    func opponentDiscardCard(card: Card) { //pseudo discard
        //print("opponent attempting to discard...")
        guard phase == .animationPhase else {
            //print("not animation phase! skipping!")
            return }
        opponentHand.remove(at: self.indexDiscardedFrom!)
        discardPile.append(card)
        SoundManager.instance.playCardSlap()
        self.playerHasWon = GinRummyValidator.canMeldAllCards(hand: self.opponentHand)
        if self.opponentHasWon {
            SoundManager.instance.playGameWin(didWin: false)
            phase = .gameEndPhase
        } else { phase = .drawPhase }
    }
    
    func saveMidTurnState(conversationID: String) {
        guard phase == .discardPhase else { return } //only save if the user is currently in the middle of a turn
        
        if let encoded = try? JSONEncoder().encode(playerHand) {
            UserDefaults.standard.set(encoded, forKey: "midTurn_\(conversationID)")
        }
    }
    
    func clearMidTurnState(conversationID: String) {
        UserDefaults.standard.removeObject(forKey: "midTurn_\(conversationID)")
    }
    
    func loadState(_ state: GameState, isPlayersTurn: Bool, conversationID: String) { //didRecieve, didSelect triggers upon sending as well, triggering loadState. in a perfect world, this would only trigger upon *recieving* a move from the opponent, but that can be changed later. Right now it triggers both times so there is slight repetition
        //print("loading state...")
        guard state.discardPile.last != self.discardPile.last else {
            //print("loading state blocked")
            return } //only guards against updating when *sending* a move (MAYBE NOT ANYMORE)
        
        self.deck = state.deck
        self.discardPile = state.discardPile
        
        if isPlayersTurn,
           let data = UserDefaults.standard.data(forKey: "midTurn_\(conversationID)"),
           let stashedHand = try? JSONDecoder().decode([Card].self, from: data) { //the user is mid-turn...
            //print("loading mid-turn state")
            self.playerHand = stashedHand
            self.phase = .discardPhase
            
        } else if isPlayersTurn { //the user is beginning their turn...
            //print("loading full turn with animations")
            self.playerHand = state.receiverHand
            let hasVisualsToAnimate = applyOpponentTurnVisuals(state: state)
            if hasVisualsToAnimate {
                syncGameFlow(isPlayersTurn: isPlayersTurn) //<- will always be true here
            } else {
                checkWin() //this would be a first turn win. chance of that is 1 in 308,984!
                if playerHasWon || opponentHasWon {
                    self.phase = .gameEndPhase
                    SoundManager.instance.playGameWin(didWin: self.playerHasWon)
                } else {
                    self.phase = .drawPhase
                }
            }
            
        } else { //it is not the players turn...
            //print("loading, and it is not the opponent's turn...")
            self.playerHand = state.senderHand
            self.opponentHand = state.receiverHand
            syncGameFlow(isPlayersTurn: isPlayersTurn) //<- will always be false here
        }
    }
    
    private func applyOpponentTurnVisuals(state: GameState) -> Bool {
        guard let discardedIndex = state.indexSenderDiscardedFrom,
              let drawnIndex = state.indexSenderDrewTo else {
            self.opponentHand = state.senderHand //first turn! simple init, no turn to show
            return false
        }
        
        self.opponentDrewFromDeck = state.senderDrewFromDeck
        self.indexDrawnTo = drawnIndex
        self.indexDiscardedFrom = discardedIndex
        
        var opponentsHandPreAnimation = state.senderHand
        let cardTheyDiscarded = self.discardPile.popLast()! //we will animate it back later...
        opponentsHandPreAnimation.insert(cardTheyDiscarded, at: discardedIndex)
        let cardToReturn = opponentsHandPreAnimation.remove(at: drawnIndex)
        if self.opponentDrewFromDeck {
            self.deck.append(cardToReturn)
        } else {
            self.discardPile.append(cardToReturn)
        }
        self.opponentHand = opponentsHandPreAnimation
        
        return true
    }
    
    private func syncGameFlow(isPlayersTurn: Bool) { //could use some refactoring. this function is called 2x and something similar is called. the equivalent of this code block is called 3x
        checkWin()
        if playerHasWon || opponentHasWon {
            self.phase = .gameEndPhase
            SoundManager.instance.playGameWin(didWin: self.playerHasWon)
        } else {
            // only enter animation phase if it's our turn to watch the opponent move
            self.phase = isPlayersTurn ? .animationPhase : .idlePhase
        }
    }
    
    func checkWin() {
        self.playerHasWon = GinRummyValidator.canMeldAllCards(hand: self.playerHand)
        self.opponentHasWon = GinRummyValidator.canMeldAllCards(hand: self.opponentHand)
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
        newDiscardPile.append(newDeck.popLast()!)
        
        let currentGameState = GameState(
            deck: newDeck,
            discardPile: newDiscardPile,
            senderHand: newPlayerHand,
            receiverHand: newOpponentHand,
            senderDrewFromDeck: false, //defaults to discard pile but shouldnt animate if these are nil:
            indexSenderDrewTo: nil,
            indexSenderDiscardedFrom: nil)
        
        return currentGameState
    }
    
    func sendGameState() {
        let currentGameState = GameState(
            deck: self.deck,
            discardPile: self.discardPile,
            senderHand: self.playerHand,
            receiverHand: self.opponentHand,
            senderDrewFromDeck: self.opponentDrewFromDeck, //this defaults to discard pile
            indexSenderDrewTo: self.indexDrawnTo,
            indexSenderDiscardedFrom: self.indexDiscardedFrom
        )
        
        onTurnCompleted?(currentGameState) //send data to MessagesViewController
    }
    
}
