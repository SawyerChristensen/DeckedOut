//
//  Crazy8sManager.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 2/23/26.
//

import Foundation

// The game snapshot for sending the game over iMessage
struct Crazy8sGameState: Codable {
    let sessionID: UUID
    let deck: [Card]
    let discardPile: [Card]
    let senderHand: [Card]
    let receiverHand: [Card]
    let cardsOpponentDrew: Int
    let didDiscard: Bool
    let activeSuitOverride: Suit?
    let turnNumber: Int
}

// MARK: The Game Engine
class Crazy8sManager: ObservableObject, GameEngine {
    static let shared = Crazy8sManager()
    
    @Published var sessionID: UUID? = nil
    @Published var deck: [Card] = []
    @Published var discardPile: [Card] = []
    @Published var playerHand: [Card] = []
    @Published var opponentHand: [Card] = []
    @Published var cardsOpponentDrew: Int = 0
    @Published var cardsDrawnThisTurn: Int = 0 //user version that replaces above int
    @Published var userDidDiscard: Bool = false
    @Published var activeSuitOverride: Suit?
    @Published var turnNumber: Int = 0
    @Published var phase: TurnPhase = .animationPhase //stays local
    @Published var userCanDiscard: Bool = false //stays local
    @Published var userNeedsToChooseSuit: Bool = false //stays local
    @Published var playerHasWon: Bool = false //stays local
    @Published var opponentHasWon: Bool = false //stays local
    @Published var opponentCardPendingDiscard: Card? = nil // Holds the card waiting in the wings
    @Published var opponentCardAnimatingToDiscard: Card? = nil       // The trigger the view actually watches
    var hasPerformedInitialLoad: Bool = false //stays local. this is just for the 0.5 delay in game view when you open a message
    
    private init() {} // values are already initialized here ^
    
    // The View Controller will listen to this to know when to send the message
    var onTurnCompleted: ((Data, GameType) -> Void)?
    
    enum TurnPhase {
        case animationPhase // Animating the opponents turn before your own
        case mainPhase      // Draw or discard!
        case idlePhase      // Opponent's turn
        case gameEndPhase   // Only unlocked upon a player winning
    }
    
    func checkHandPlayability(){
        guard let topCard = discardPile.last else {
            userCanDiscard = false
            return
        }
        
        userCanDiscard = playerHand.contains { card in
            if card.rank == .eight { //8s are wild! always playable!
                return true
            }
            
            if let requiredSuit = activeSuitOverride { //If the opponent played an 8, user must match their declared suit
                return card.suit == requiredSuit
            }
            
            return card.suit == topCard.suit || card.rank == topCard.rank
        }
    }
    
    func drawFromDeck() { //CHECK IF THE USER HAS DRAWN 3 TIMES THIS TURN, IF TRUE, SEND GAME STATE AND SWITCH GAME PHASE
        guard phase == .mainPhase, !deck.isEmpty, !userCanDiscard else { return }
        let card = deck.popLast()! //maybe make this a guard statement? this does the samething in the earlier guard statement...
        //add index drawn to (in the case the user reorders their hand?)
        playerHand.append(card)
        checkHandPlayability() //CALL THIS IN LOAD!!
        cardsDrawnThisTurn += 1
        
        if cardsDrawnThisTurn == 3 && !userCanDiscard { //if youve drawn your 3rd card and still cannot play it, the user has to pass
            phase = .idlePhase
            sendGameState()
        }
    }
    
    func discardCard(card: Card) { // Removed chosenSuit from here, we'll handle it separately
        guard let topCard = discardPile.last else { return }
        
        let isEight = card.rank == .eight
        let matchesSuit = (activeSuitOverride != nil) ? (card.suit == activeSuitOverride) : (card.suit == topCard.suit)
        let matchesRank = (card.rank == topCard.rank)
        let isLegalPlay = isEight || matchesSuit || matchesRank
        
        guard phase == .mainPhase, isLegalPlay, let index = playerHand.firstIndex(of: card) else {
            SoundManager.instance.playErrorFeedback()
            return
        }
        
        playerHand.remove(at: index)
        discardPile.append(card)
        SoundManager.instance.playCardSlap()

        if card.rank == .eight {
            userNeedsToChooseSuit = true //signals GameView to prompt the user for a new suit
        } else {
            activeSuitOverride = nil
            completeTurn()
        }
    }
    
    func submitChosenSuit(_ suit: Suit) {
        activeSuitOverride = suit
        userNeedsToChooseSuit = false
        completeTurn()
    }
    
    private func completeTurn() {
        playerHasWon = playerHand.isEmpty
        if playerHasWon {
            SoundManager.instance.playGameEnd(didWin: true)
            phase = .gameEndPhase
            WinTracker.shared.incrementWins(for: "Crazy 8s")
        } else {
            phase = .idlePhase
        }
        
        sendGameState()
    }
    
    func opponentDrawFromDeck() {
        guard phase == .animationPhase,
              !deck.isEmpty else {
            return
        }
        let card = deck.popLast()!
        opponentHand.append(card)
    }
    
    func opponentDiscardCard(card: Card) { //pseudo discard
        guard phase == .animationPhase else {
            return }
        opponentHand.removeLast()
        discardPile.append(card)
        SoundManager.instance.playCardSlap()
        
        opponentHasWon = opponentHand.isEmpty
        if opponentHasWon {
            SoundManager.instance.playGameEnd(didWin: false)
            phase = .gameEndPhase
        } else {
            //ANIMATE THE OPPONENTS DECISION FOR WHAT SUIT THEY DECIDED IF CARD DISCARDED WAS AN 8
            phase = .mainPhase
            checkHandPlayability()
        }
    }
    
    private func reshuffleDiscardIntoDeck() { //for when the deck count is 1 (could be refactored)
        let topDeck = deck.popLast()!
        let topDiscard = discardPile.popLast()! //this is the card the user discarded
        let secondDiscard = discardPile.popLast()! //need 2 cards in the discard pile so when we ready the opponent animation there is still a card there...
        deck = discardPile.shuffled()
        deck.append(topDeck)
        discardPile = [secondDiscard, topDiscard]
    }
    
    func saveMidTurnState(conversationID: String) { //not needed in Crazy 8s, but needed to conform to our GameEngine protocol
        return
    }
    
    func clearMidTurnState(conversationID: String) {
        return
    }
    
    func loadState(from data: Data, isPlayersTurn: Bool, conversationID: String, isExplicitChange: Bool = false) {
        guard let state = try? JSONDecoder().decode(Crazy8sGameState.self, from: data) else {
            print("Error: Failed to decode Crazy8sGameState from data.")
            return
        }
        
        let isInitialLoad = (self.sessionID == nil) //is the game manager currently empty? (user is on main menu and hasnt tapped a bubble yet)
        let isSameSession = (self.sessionID == state.sessionID) //is this the game we are already looking at?
        let isNewTurn = state.turnNumber > self.turnNumber //is it a newer turn than what we have in memory?
        
        guard isInitialLoad || (isSameSession && isNewTurn) || isExplicitChange else { //(if any are true) allow if: (We haven't loaded a session yet) OR (It is the same session AND theres progress in the session) OR (the user is explicitly changing the game session)
            /*if !isSameSession && !isInitialLoad {
                print("Action Blocked: User tried to load session \(state.sessionID) while active in \(self.sessionID!)")
            } else {
                print("Action Blocked: Turn \(state.turnNumber) is not newer than \(self.turnNumber)")
            }*/
            return
        }
        
        if isExplicitChange {
            resetToInit() //may not be neccesary, but better safe than sorry (this is open for review)
        }
        
        self.sessionID = state.sessionID
        self.turnNumber = state.turnNumber
        self.deck = state.deck
        self.discardPile = state.discardPile
        
        if isPlayersTurn { //the user is beginning their turn...
            self.playerHand = state.receiverHand
            let hasVisualsToAnimate = applyOpponentTurnVisuals(state: state)
            if hasVisualsToAnimate { //it is NOT the first turn...
                phase = .animationPhase
            } else { //it IS the first turn...
                phase = .mainPhase
                checkHandPlayability()
            }
        } else { //it is not the players turn...
            self.playerHand = state.senderHand
            self.opponentHand = state.receiverHand
            playerHasWon = self.playerHand.isEmpty
            if playerHasWon {
                phase = .gameEndPhase
                SoundManager.instance.playGameEnd(didWin: self.playerHasWon)
            } else {
                phase = .idlePhase
            }
        }
    }
    
    private func resetToInit() {
        self.sessionID = nil
        self.playerHand = []
        self.opponentHand = []
        self.deck = []
        self.discardPile = []
        self.phase = .animationPhase
        self.userCanDiscard = false
        self.activeSuitOverride = nil
        self.cardsDrawnThisTurn = 0
        self.cardsOpponentDrew = 0
        self.playerHasWon = false
        self.opponentHasWon = false
        self.turnNumber = 0
    }
    
    private func applyOpponentTurnVisuals(state: Crazy8sGameState) -> Bool {
        guard turnNumber > 0 else {
            self.opponentHand = state.senderHand //first turn! simple init, no turn to show
            return false
        }
        
        var opponentsHandPreAnimation = state.senderHand
        self.cardsOpponentDrew = state.cardsOpponentDrew
        
        if state.didDiscard {
            let cardTheyDiscarded = discardPile.popLast()! //we will animate it back later...
            self.opponentCardPendingDiscard = cardTheyDiscarded
            opponentsHandPreAnimation.append(cardTheyDiscarded)
        } else {
            self.opponentCardPendingDiscard = nil
        }
        
        for _ in 0..<cardsOpponentDrew {
            if !opponentsHandPreAnimation.isEmpty { //do we really need to check this? this might be pointless
                let cardToReturn = opponentsHandPreAnimation.removeLast()
                deck.append(cardToReturn)
            }
        }
        
        opponentHand = opponentsHandPreAnimation
        return true
    }
    
    func createNewGameState(withHandSize: Int) -> Data? {
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
        
        let initialState = Crazy8sGameState(
            sessionID: newSessionID,
            deck: newDeck,
            discardPile: newDiscardPile,
            senderHand: newPlayerHand,
            receiverHand: newOpponentHand,
            cardsOpponentDrew: 0,
            didDiscard: false,
            activeSuitOverride: nil,
            turnNumber: 0)
        
        return try? JSONEncoder().encode(initialState)
    }
    
    func sendGameState() {
        if deck.count == 1 { reshuffleDiscardIntoDeck() }
        
        let currentGameState = Crazy8sGameState(
            sessionID: self.sessionID!,
            deck: self.deck,
            discardPile: self.discardPile,
            senderHand: self.playerHand,
            receiverHand: self.opponentHand,
            cardsOpponentDrew: self.cardsDrawnThisTurn,
            didDiscard: self.userDidDiscard,
            activeSuitOverride: activeSuitOverride,
            turnNumber: self.turnNumber + 1
        )
        
        guard let stateData = try? JSONEncoder().encode(currentGameState) else {
            print("Error: Failed to encode Crazy8sGameState into Data.")
            return
        }
        
        self.onTurnCompleted?(stateData, .crazy8s) //send data to MessagesViewController
    }
    
}
