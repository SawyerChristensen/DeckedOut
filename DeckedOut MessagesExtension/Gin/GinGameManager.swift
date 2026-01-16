//
//  GinGameManager.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 11/26/25.
//

import Foundation

// The game snapshot for sending the game over iMessage
struct GameState: Codable {
    let sessionID: UUID
    let deck: [Card]
    let discardPile: [Card]
    let senderHand: [Card]
    let receiverHand: [Card]
    let senderDrewFromDeck: Bool
    let indexSenderDrewTo: Int?
    let indexSenderDiscardedFrom: Int?
    let turnNumber: Int
}

// MARK: The Game Engine
class GameManager: ObservableObject {
    @Published var sessionID: UUID? = nil
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
    @Published var turnNumber: Int = 0
    
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
            WinTracker.shared.incrementWins()
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
        self.opponentHasWon = GinRummyValidator.canMeldAllCards(hand: self.opponentHand)
        if self.opponentHasWon {
            SoundManager.instance.playGameWin(didWin: false)
            phase = .gameEndPhase
        } else { phase = .drawPhase }
    }
    
    private func reshuffleDiscardIntoDeck() { //for when the deck count is 1 (could be refactored)
        let topDeck = deck.popLast()!
        let topDiscard = discardPile.popLast()! //this is the card the user discarded
        let secondDiscard = discardPile.popLast()! //need 2 cards in the discard pile so when we ready the opponent animation there is still a card there...
        self.deck = discardPile.shuffled()
        self.deck.append(topDeck)
        self.discardPile = [secondDiscard, topDiscard]
    }
    
    func saveMidTurnState(conversationID: String) {
        guard phase == .discardPhase, let sID = sessionID else { return } //only save if the user is currently in the middle of a turn
        
        if let encoded = try? JSONEncoder().encode(playerHand) {
            UserDefaults.standard.set(encoded, forKey: "midTurn_\(sID.uuidString)")
        }
    }
    
    func clearMidTurnState(conversationID: String) {
        guard let sID = sessionID else { return }
        UserDefaults.standard.removeObject(forKey: "midTurn_\(sID.uuidString)")
    }
    
    func loadState(_ state: GameState, isPlayersTurn: Bool, isExplicitTap: Bool, conversationID: String) { //didRecieve, didSelect calls this upon sending as well!
        let isInitialLoad = (self.sessionID == nil) //is the game manager currently empty? (user is on main menu)
        let isSameSession = (self.sessionID == state.sessionID) //is this the game we are already looking at?
        let isNewTurn = state.turnNumber > self.turnNumber //is it a newer turn than what we have in memory?
        
        guard isInitialLoad || isExplicitTap || (isSameSession && isNewTurn) else { //allow if: (We haven't loaded a session yet) OR (It is the same session AND theres progress in the session)
            /*if !isSameSession && !isInitialLoad {
                print("Action Blocked: User tried to load session \(state.sessionID) while active in \(self.sessionID!)")
            } else {
                print("Action Blocked: Turn \(state.turnNumber) is not newer than \(self.turnNumber)")
            }*/
            return
        }
        
        self.sessionID = state.sessionID
        self.deck = state.deck
        self.discardPile = state.discardPile
        
        if isPlayersTurn, //does not check if this is the same game session!! just the same conversation!!
           let data = UserDefaults.standard.data(forKey: "midTurn_\(state.sessionID.uuidString)"),
           let stashedHand = try? JSONDecoder().decode([Card].self, from: data) { //the user is mid-turn...
            print("loading mid-turn state")
            self.playerHand = stashedHand
            self.opponentHand = state.senderHand
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
        //print("Readying opponent turn visuals") //this seems to get triggered multiple times?
        
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
    
    func createNewGameState(withHandSize: Int) -> GameState { //should we also set these values to self??
        let newSessionID = UUID()
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
            sessionID: newSessionID,
            deck: newDeck,
            discardPile: newDiscardPile,
            senderHand: newPlayerHand,
            receiverHand: newOpponentHand,
            senderDrewFromDeck: false, //defaults to discard pile but shouldnt animate if these are nil:
            indexSenderDrewTo: nil,
            indexSenderDiscardedFrom: nil,
            turnNumber: 0)
        
        return currentGameState
    }
    
    func sendGameState() {
        if deck.count == 1 { reshuffleDiscardIntoDeck() }
        let currentGameState = GameState(
            sessionID: self.sessionID!,
            deck: self.deck,
            discardPile: self.discardPile,
            senderHand: self.playerHand,
            receiverHand: self.opponentHand,
            senderDrewFromDeck: self.opponentDrewFromDeck, //this defaults to discard pile
            indexSenderDrewTo: self.indexDrawnTo,
            indexSenderDiscardedFrom: self.indexDiscardedFrom,
            turnNumber: self.turnNumber + 1
        )
        
        onTurnCompleted?(currentGameState) //send data to MessagesViewController
    }
    
}
