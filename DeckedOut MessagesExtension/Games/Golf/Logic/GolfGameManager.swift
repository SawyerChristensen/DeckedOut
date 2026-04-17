//
//  GolfGameManager.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 4/15/26.
//

import Foundation

// The game snapshot for sending the game over iMessage
struct GolfGameState: Codable {
    let sessionID: UUID
    let deck: [Card]
    let discardPile: [Card]
    let senderHand: [Card]
    let receiverHand: [Card]
    let senderDrewFromDeck: Bool
    let indexSenderReplaced: Int?
    let turnNumber: Int
}

// MARK: The Game Engine
class GolfManager: ObservableObject, GameEngine {
    static let shared = GolfManager()
    
    @Published var sessionID: UUID? = nil
    @Published var playerHand: [Card] = []
    @Published var opponentHand: [Card] = []
    @Published var deck: [Card] = []
    @Published var discardPile: [Card] = []
    @Published var phase: TurnPhase = .animationPhase //stays local
    @Published var opponentDrewFromDeck: Bool = false
    @Published var hoveringCard: Card? = nil
    @Published var indexReplaced: Int? = nil
    @Published var playerHasWon: Bool = false //stays local
    @Published var opponentHasWon: Bool = false //stays local
    @Published var turnNumber: Int = 0
    
    var hasPerformedInitialLoad: Bool = false //stays local. this is just for the 0.5 delay in game view when you open a message
    
    private init() {} // values are already initialized here ^
    
    // The View Controller will listen to this to know when to send the message
    var onTurnCompleted: ((Data, GameType) -> Void)?
    
    enum TurnPhase {
        case animationPhase // Animating the opponents turn before your own
        case drawPhase      // Waiting for user to pick from Deck or Discard
        case placementPhase // Waiting for user to pick a card to replace (and send to the discard)
        case idlePhase      // Opponent's turn
        case gameEndPhase   // Only unlocked upon winning
    }
    
    
    func drawFromDeck() {
        guard phase == .drawPhase, !deck.isEmpty else { return }
        let card = deck.popLast()! //maybe make this a guard statement? this does the samething in the earlier guard statement...
        hoveringCard = card
        opponentDrewFromDeck = true
        phase = .placementPhase
    }
    
    func drawFromDiscard() {
        guard phase == .drawPhase, !discardPile.isEmpty else { return }
        let card = discardPile.popLast()!
        hoveringCard = card
        opponentDrewFromDeck = false
        phase = .placementPhase
    }
    
    func replaceCard(at index: Int) {
        guard phase == .placementPhase,
              playerHand.indices.contains(index),
              let drawn = hoveringCard else { return }
        let oldCard = playerHand[index]
        indexReplaced = index
        playerHand[index] = drawn
        discardPile.append(oldCard)
        hoveringCard = nil
        SoundManager.instance.playCardSlap()
        //playerHasWon = GolfValidator.canMeldAllCards(hand: playerHand)
        if playerHasWon {
            SoundManager.instance.playGameEnd(didWin: true)
            phase = .gameEndPhase
            WinTracker.shared.incrementWins(for: "Golf")
        } else { phase = .idlePhase }
        sendGameState()
    }
    
    /// Animates the opponent's swap: draws a card from the appropriate source,
    /// replaces the card at `indexReplaced` in the opponent's hand, and discards the replaced card.
    func opponentReplaceCard() {
        guard phase == .animationPhase,
              let replaceIndex = indexReplaced else {
            return
        }
        
        // Draw the new card from deck or discard
        let drawnCard: Card
        if opponentDrewFromDeck {
            guard !deck.isEmpty else { return }
            drawnCard = deck.popLast()!
        } else {
            guard !discardPile.isEmpty else { return }
            drawnCard = discardPile.popLast()!
        }
        
        // Swap: replace the card at the index, discard the old one
        let replacedCard = opponentHand[replaceIndex]
        opponentHand[replaceIndex] = drawnCard
        discardPile.append(replacedCard)
        
        SoundManager.instance.playCardSlap()
        //opponentHasWon = GolfValidator.canMeldAllCards(hand: opponentHand)
        if opponentHasWon {
            SoundManager.instance.playGameEnd(didWin: false)
            phase = .gameEndPhase
        } else {
            phase = .drawPhase
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
    
    func saveMidTurnState(conversationID: String) {
        guard phase == .placementPhase, let sID = sessionID else { return } //only save if the user is currently in the middle of a turn
        
        if let encoded = try? JSONEncoder().encode(hoveringCard) {
            UserDefaults.standard.set(encoded, forKey: "midTurn_\(sID.uuidString)")
        }
    }
    
    func clearMidTurnState(conversationID: String) {
        guard let sID = sessionID else { return }
        UserDefaults.standard.removeObject(forKey: "midTurn_\(sID.uuidString)")
    }
    
    func loadState(from data: Data, isPlayersTurn: Bool, conversationID: String, isExplicitChange: Bool = false) {
        guard let state = try? JSONDecoder().decode(GolfGameState.self, from: data) else {
            print("Error: Failed to decode GolfGameState from data.")
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
        
        if isPlayersTurn,
           let data = UserDefaults.standard.data(forKey: "midTurn_\(state.sessionID.uuidString)"),
           let stashedHoveringCard = try? JSONDecoder().decode(Card.self, from: data) { //the user is mid-turn...
            self.hoveringCard = stashedHoveringCard
            self.playerHand = state.receiverHand
            self.opponentHand = state.senderHand
            if let topDeckCard = deck.last,
               stashedHoveringCard.id == topDeckCard.id { // the user previously drew from the deck
                deck.removeLast()
            } else { //the user drew from the discard pile instead
                discardPile.removeLast()
            }
            phase = .placementPhase
            
        } else if isPlayersTurn { //the user is beginning their turn...
            self.playerHand = state.receiverHand
            let hasVisualsToAnimate = applyOpponentTurnVisuals(state: state)
            if hasVisualsToAnimate {//it is not the first turn...
                phase = .animationPhase
            } else { //it is the first turn...
                phase = .drawPhase
            }
            
        } else { //it is not the players turn...
            self.playerHand = state.senderHand
            self.opponentHand = state.receiverHand
            //playerHasWon = GolfValidator.canMeldAllCards(hand: self.playerHand)
            if playerHasWon {
                phase = .gameEndPhase
                SoundManager.instance.playGameEnd(didWin: self.playerHasWon)
            } else {
                // only enter animation phase if it's our turn to watch the opponent move
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
        self.opponentDrewFromDeck = false
        self.hoveringCard = nil
        self.indexReplaced = nil
        self.playerHasWon = false
        self.opponentHasWon = false
        self.turnNumber = 0
    }
    
    private func applyOpponentTurnVisuals(state: GolfGameState) -> Bool {
        guard let replacedIndex = state.indexSenderReplaced else {
            self.opponentHand = state.senderHand //first turn! simple init, no turn to show
            return false
        }
        
        self.opponentDrewFromDeck = state.senderDrewFromDeck
        self.indexReplaced = replacedIndex
        
        // The state contains the hand AFTER the swap. We need to undo it so we can animate it forward.
        // After their turn: hand[replacedIndex] = drawnCard, and the old card is on top of discardPile.
        var opponentsHandPreAnimation = state.senderHand
        let cardTheyDiscarded = discardPile.popLast()! // the old card they replaced (top of discard)
        let cardTheyDrew = opponentsHandPreAnimation[replacedIndex] // the new card they placed
        
        // Undo the swap: put the old card back, return the drawn card to its source
        opponentsHandPreAnimation[replacedIndex] = cardTheyDiscarded
        if opponentDrewFromDeck {
            deck.append(cardTheyDrew)
        } else {
            discardPile.append(cardTheyDrew)
        }
        opponentHand = opponentsHandPreAnimation
        
        return true
    }
    
    func checkWin() { //set for deprecation when we disallow first turn wins
        //playerHasWon = GolfValidator.canMeldAllCards(hand: playerHand)
        //opponentHasWon = GolfValidator.canMeldAllCards(hand: opponentHand)
    }
    
    func createNewGameState() -> Data? {
        let newSessionID = UUID()
        var newDeck = Deck().cards
        var newPlayerHand: [Card] = []
        var newOpponentHand: [Card] = []
        for _ in 0..<6 {
            newPlayerHand.append(newDeck.popLast()!) //see if removefirst, remove last is faster
            newOpponentHand.append(newDeck.popLast()!)
        }
        var newDiscardPile: [Card] = []
        newDiscardPile.append(newDeck.popLast()!)
        
        let initialState = GolfGameState(
            sessionID: newSessionID,
            deck: newDeck,
            discardPile: newDiscardPile,
            senderHand: newPlayerHand,
            receiverHand: newOpponentHand,
            senderDrewFromDeck: false, //defaults to user drawing from discard pile but shouldnt matter if this is also nil:
            indexSenderReplaced: nil,
            turnNumber: 0)
        
        return try? JSONEncoder().encode(initialState)
    }
    
    func sendGameState() {
        if deck.count == 1 { reshuffleDiscardIntoDeck() }
        
        let currentGameState = GolfGameState(
            sessionID: self.sessionID!,
            deck: self.deck,
            discardPile: self.discardPile,
            senderHand: self.playerHand,
            receiverHand: self.opponentHand,
            senderDrewFromDeck: self.opponentDrewFromDeck,
            indexSenderReplaced: self.indexReplaced,
            turnNumber: self.turnNumber + 1
        )
        
        guard let stateData = try? JSONEncoder().encode(currentGameState) else {
            print("Error: Failed to encode GolfGameState into Data.")
            return
        }
        
        self.onTurnCompleted?(stateData, .golf) //send data to MessagesViewController
    }
    
}

