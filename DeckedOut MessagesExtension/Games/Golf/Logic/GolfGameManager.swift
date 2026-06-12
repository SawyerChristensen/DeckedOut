//
//  GolfGameManager.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 4/15/26.
//

import Foundation

// V1: Legacy 2-player game snapshot
struct GolfGameState: Codable, BasicGameState {
    let sessionID: UUID
    let deck: [Card]
    let discardPile: [Card]
    let senderHand: [Card]
    let receiverHand: [Card]
    let senderDrewFromDeck: Bool
    let indexSenderReplaced: Int?
    let turnNumber: Int
    let senderFaceUpIndices: Set<Int>
    let receiverFaceUpIndices: Set<Int>
    let senderCardBack: String? //the card-back the sender has equipped; optional for backward compat
}

// V2: Seat-based groupchat multiplayer game snapshot
struct GolfV2GameState: Codable, V2GameState {
    let sessionID: UUID
    let deck: [Card]
    let discardPile: [Card]
    let seats: [UUID]
    let hands: [[Card]]
    let currentSeatIndex: Int
    let turnNumber: Int
    let lastPlayerDrewFromDeck: Bool
    let lastPlayerIndexReplaced: Int?
    let faceUpIndices: [Set<Int>]
    let goingOutSeat: Int?
    let seatCardBacks: [String]? //parallel to seats; optional for backward compat
}

// MARK: The Game Engine
class GolfManager: ObservableObject, GameEngine, GroupChatCapable {
    static let shared = GolfManager()
    static let unclaimedSeat = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    @Published var extensionWidth: CGFloat = 375
    @Published var sessionID: UUID? = nil
    @Published var playerHand: [Card] = []
    @Published var opponentHand: [Card] = []
    @Published var deck: [Card] = []
    @Published var discardPile: [Card] = []
    @Published var phase: TurnPhase = .animationPhase //stays local
    @Published var drewFromDeck: Bool = false //tracks both what the opponent did and what the user does
    @Published var hoveringCard: Card? = nil
    @Published var indexReplaced: Int? = nil
    @Published var playerHasWon: Bool = false //stays local
    @Published var opponentHasWon: Bool = false //stays local
    @Published var isGameOver: Bool = false //stays local
    @Published var turnNumber: Int = 0
    @Published var playerFaceUpIndices: Set<Int> = []
    @Published var opponentFaceUpIndices: Set<Int> = []
    @Published var opponentDepartingFromIndex: Int? = nil // Animation trigger for opponent view
    @Published var playerScore: Int = 0
    @Published var opponentScore: Int = 0

    private var preTurnFaceUpIndices: Set<Int> = [] //captured before replaceCard modifies playerFaceUpIndices
    var hasPerformedInitialLoad: Bool = false //stays local. this is just for the 0.5 delay in game view when you open a message
    var isSinglePlayer: Bool = true

    // Card-back equipped by each player (sent in the message payload)
    @Published var opponentCardBack: String = "cardBackRed" //v1: the single opponent's equipped back
    @Published var seatCardBacks: [String] = [] //v2: parallel to `seats`; updated each turn

    // Multiplayer (V2) properties
    var seats: [UUID] = []
    var mySeatIndex: Int = 0
    @Published var allHands: [[Card]] = []
    @Published var allFaceUpIndices: [Set<Int>] = []
    var animatingOpponentSeat: Int = 0
    var isSpectating: Bool = false
    @Published var isAnimatingOpponentTurn: Bool = false
    @Published var isJoiningPhase: Bool = false
    @Published var isSettlingAfterJoin: Bool = false
    @Published var joinWasOverwritten: Bool = false
    var pendingJoinState: GolfV2GameState? = nil
    var localParticipantID: UUID? = nil
    var goingOutSeat: Int? = nil

    var needsToJoin: Bool {
        guard isJoiningPhase, let lpID = localParticipantID else { return false }
        return !seats.contains(lpID)
    }

    /// Returns the card-back image name for a specific seat. Falls back to `cardBackRed`.
    func cardBack(forSeat seatIndex: Int) -> String {
        if isSinglePlayer { return opponentCardBack }
        return seatCardBacks.indices.contains(seatIndex) ? seatCardBacks[seatIndex] : "cardBackRed"
    }

    /// Card-back to display on the deck/discard stacks when it isn't the user's turn.
    /// During animation, matches the seat currently drawing from the deck so the animated card and the deck share a back.
    /// Otherwise reflects the upcoming player's back so the deck updates as soon as the previous turn lands.
    var opponentDeckCardBack: String {
        if isSinglePlayer { return opponentCardBack }
        guard !seats.isEmpty else { return "cardBackRed" }
        if phase == .animationPhase || isAnimatingOpponentTurn {
            return cardBack(forSeat: animatingOpponentSeat)
        }
        let nextSeat = (animatingOpponentSeat + 1) % seats.count
        return cardBack(forSeat: nextSeat)
    }

    var playerCancelledIndices: Set<Int> {
        cancelledIndices(hand: playerHand, faceUp: playerFaceUpIndices)
    }

    var opponentCancelledIndices: Set<Int> {
        cancelledIndices(hand: opponentHand, faceUp: opponentFaceUpIndices)
    }

    private func cancelledIndices(hand: [Card], faceUp: Set<Int>) -> Set<Int> {
        guard hand.count == 6 else { return [] }
        var cancelled: Set<Int> = []
        for (top, bottom) in [(0, 3), (1, 4), (2, 5)] {
            if faceUp.contains(top) && faceUp.contains(bottom) && hand[top].rank == hand[bottom].rank {
                cancelled.insert(top)
                cancelled.insert(bottom)
            }
        }
        return cancelled
    }

    private init() {} // values are already initialized here ^

    // The View Controller will listen to these to know when to send the message
    var onTurnCompleted: ((Data, GameType) -> Void)?
    var onJoinCompleted: ((Data, GameType) -> Void)?

    enum TurnPhase {
        case animationPhase // Animating the opponents turn before your own
        case drawPhase      // Waiting for user to pick from Deck or Discard
        case placementPhase // Waiting for user to pick a card to replace (and send to the discard)
        case idlePhase      // Opponent's turn
        case gameEndPhase   // Only unlocked upon winning
    }


    func drawFromDeck() {
        guard phase == .drawPhase, !deck.isEmpty else { return }
        let card = deck.popLast()!
        hoveringCard = card
        drewFromDeck = true
        phase = .placementPhase
    }

    func drawFromDiscard() {
        guard phase == .drawPhase, !discardPile.isEmpty else { return }
        let card = discardPile.popLast()!
        hoveringCard = card
        drewFromDeck = false
        phase = .placementPhase
    }

    func replaceCard(at index: Int) {
        guard phase == .placementPhase,
              playerHand.indices.contains(index),
              let drawn = hoveringCard else { return }
        let oldCard = playerHand[index]
        indexReplaced = index
        preTurnFaceUpIndices = playerFaceUpIndices //save before modifying
        playerHand[index] = drawn
        playerFaceUpIndices.insert(index)
        discardPile.append(oldCard)
        hoveringCard = nil
        SoundManager.instance.playCardSlap()
        HapticManager.instance.playCardSlap()
        endTurn()
    }

    /// Discards the hovering card without replacing anything. Only allowed if the player drew from the deck.
    func discardDrawnCard() {
        guard phase == .placementPhase,
              drewFromDeck,
              let drawn = hoveringCard else { return }
        preTurnFaceUpIndices = playerFaceUpIndices // unchanged — no card was replaced
        indexReplaced = nil
        discardPile.append(drawn)
        hoveringCard = nil
        SoundManager.instance.playCardSlap()
        HapticManager.instance.playCardSlap()
        endTurn()
    }

    func endTurn() {
        if deck.count == 1 { reshuffleDiscardIntoDeck() }

        if isSinglePlayer {
            if opponentFaceUpIndices.count == 6 {
                resolveGameEnd(playerLastToMove: true)
            } else {
                phase = .idlePhase
            }
            sendLegacyGameState()
        } else {
            if playerFaceUpIndices.count == 6 && goingOutSeat == nil {
                goingOutSeat = mySeatIndex
            }
            let nextSeat = (mySeatIndex + 1) % seats.count
            if let goSeat = goingOutSeat, nextSeat == goSeat {
                resolveGameEndV2()
            } else {
                phase = .idlePhase
            }
            sendV2GameState()
        }
    }

    /// Animates the opponent's swap: draws a card from the appropriate source,
    /// replaces the card at `indexReplaced` in the opponent's hand, and discards the replaced card.
    func opponentReplaceCard() {
        guard phase == .animationPhase || isAnimatingOpponentTurn else {
            return
        }

        // Draw the new card from deck or discard
        let drawnCard: Card
        if drewFromDeck {
            guard !deck.isEmpty else { return }
            drawnCard = deck.popLast()!
        } else {
            guard !discardPile.isEmpty else { return }
            drawnCard = discardPile.popLast()!
        }
        let cardToDiscard: Card

        if let replaceIndex = indexReplaced { //theyre swapping from hand
            // Swap: replace the card at the index, discard the old one
            cardToDiscard = opponentHand[replaceIndex]
            opponentHand[replaceIndex] = drawnCard
            opponentFaceUpIndices.insert(replaceIndex)
        } else { //theyre drawing from deck and discarding
            cardToDiscard = drawnCard
        }

        // Keep the V2 multi-opponent grid in sync. The network state ships the sender's
        // face-up indices as PRE-turn (so the next player can animate), which means
        // allFaceUpIndices[animatingOpponentSeat] is missing the just-replaced index.
        // Without this, the static view that takes over from the animated view would
        // render the new card face-down until the next turn arrives.
        if !isSinglePlayer,
           allHands.indices.contains(animatingOpponentSeat),
           allFaceUpIndices.indices.contains(animatingOpponentSeat) {
            allHands[animatingOpponentSeat] = opponentHand
            allFaceUpIndices[animatingOpponentSeat] = opponentFaceUpIndices
        }

        discardPile.append(cardToDiscard)
        SoundManager.instance.playCardSlap()
        HapticManager.instance.playCardSlap()

        if isSinglePlayer {
            if playerFaceUpIndices.count == 6 {
                resolveGameEnd(playerLastToMove: false)
            } else {
                phase = .drawPhase
            }
        } else if isAnimatingOpponentTurn {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.isAnimatingOpponentTurn = false
            }
        } else {
            if goingOutSeat == mySeatIndex {
                resolveGameEndV2()
            } else {
                phase = .drawPhase
            }
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

    func loadState(from data: Data, isPlayersTurn: Bool, localParticipantID: UUID = UUID(), isSinglePlayer: Bool = true, conversationID: String, isExplicitChange: Bool = false) {
        if isSinglePlayer == false, let v2State = try? JSONDecoder().decode(GolfV2GameState.self, from: data) {
            loadV2State(state: v2State, localParticipantID: localParticipantID, conversationID: conversationID, isExplicitChange: isExplicitChange)
        } else if let state = try? JSONDecoder().decode(GolfGameState.self, from: data) {
            loadLegacyState(state: state, isPlayersTurn: isPlayersTurn, conversationID: conversationID, isExplicitChange: isExplicitChange)
        } else {
            print("Error: Failed to decode GolfGameState from data.")
        }
    }

    private func loadLegacyState(state: GolfGameState, isPlayersTurn: Bool, conversationID: String, isExplicitChange: Bool) {
        let isInitialLoad = (self.sessionID == nil) //is the game manager currently empty? (user is on main menu and hasnt tapped a bubble yet)
        let isSameSession = (self.sessionID == state.sessionID) //is this the game we are already looking at?
        let isNewTurn = state.turnNumber > self.turnNumber //is it a newer turn than what we have in memory?

        guard isInitialLoad || (isSameSession && isNewTurn) || isExplicitChange else { return }

        if isExplicitChange {
            resetToInit()
        }

        self.isSinglePlayer = true
        self.sessionID = state.sessionID
        self.turnNumber = state.turnNumber
        self.deck = state.deck
        self.discardPile = state.discardPile
        if isPlayersTurn, let sentBack = state.senderCardBack {
            self.opponentCardBack = sentBack
        }

        // senderFaceUpIndices is the PRE-TURN state (before the sender replaced a card).
        // For animation, this is correct as-is. For non-animation cases, reconstruct the post-turn state.

        if isPlayersTurn,
           let data = UserDefaults.standard.data(forKey: "midTurn_\(state.sessionID.uuidString)"),
           let stashedHoveringCard = try? JSONDecoder().decode(Card.self, from: data) { //the user is mid-turn...
            self.hoveringCard = stashedHoveringCard
            self.playerHand = state.receiverHand
            self.opponentHand = state.senderHand
            self.playerFaceUpIndices = state.receiverFaceUpIndices
            // Opponent already completed their turn; reconstruct post-turn face-up
            var opponentFaceUp = state.senderFaceUpIndices
            if let idx = state.indexSenderReplaced { opponentFaceUp.insert(idx) }
            self.opponentFaceUpIndices = opponentFaceUp
            if let topDeckCard = deck.last,
               stashedHoveringCard.id == topDeckCard.id { // the user previously drew from the deck
                deck.removeLast()
            } else { //the user drew from the discard pile instead
                discardPile.removeLast()
            }
            phase = .placementPhase

        } else if isPlayersTurn { //the user is beginning their turn...
            self.playerHand = state.receiverHand
            self.playerFaceUpIndices = state.receiverFaceUpIndices
            self.opponentFaceUpIndices = state.senderFaceUpIndices //pre-turn: correct for animation
            let hasVisualsToAnimate = applyOpponentTurnVisuals(state: state)
            if hasVisualsToAnimate {//it is not the first turn...
                phase = .animationPhase
            } else { //it is the first turn...
                phase = .drawPhase
            }

        } else { //it is not the players turn...
            self.playerHand = state.senderHand
            self.opponentHand = state.receiverHand
            // Reconstruct the sender's post-turn face-up (sender = this player when not their turn)
            var senderFaceUp = state.senderFaceUpIndices
            if let idx = state.indexSenderReplaced { senderFaceUp.insert(idx) }
            self.playerFaceUpIndices = senderFaceUp
            self.opponentFaceUpIndices = state.receiverFaceUpIndices
            if opponentFaceUpIndices.count == 6 {
                resolveGameEnd(playerLastToMove: true) //from the perspective of the player last to move
            } else {
                // only enter animation phase if it's our turn to watch the opponent move
                phase = .idlePhase
            }
        }
    }

    private func loadV2State(state: GolfV2GameState, localParticipantID: UUID, conversationID: String, isExplicitChange: Bool) {
        let isInitialLoad = (self.sessionID == nil)
        let isSameSession = (self.sessionID == state.sessionID)
        let isNewTurn = state.turnNumber > self.turnNumber
        let isConcurrentWinner = isSameSession &&
                                    (state.turnNumber == self.turnNumber) &&
                                    (state.seats.map { $0.uuidString }.joined() > self.seats.map { $0.uuidString }.joined())

        guard isExplicitChange || isInitialLoad || (isSameSession && isNewTurn) || isConcurrentWinner else {
            return
        }
        if isExplicitChange { resetToInit() }
        
        let isMissingUserID = !state.seats.contains(localParticipantID)
        if isMissingUserID { //if the user is missing from seats...
            let joinRecord = "golf_joined_\(state.sessionID.uuidString)"
            if UserDefaults.standard.data(forKey: joinRecord) != nil { //but we have a record of them joining
                self.localParticipantID = localParticipantID
                self.pendingJoinState = state
                self.seats = state.seats
                self.turnNumber = state.turnNumber
                self.isJoiningPhase = true
                self.joinWasOverwritten = true
                return
            }
        }

        self.localParticipantID = localParticipantID
        self.isSinglePlayer = false
        self.sessionID = state.sessionID
        self.turnNumber = state.turnNumber
        self.seats = state.seats
        self.deck = state.deck
        self.discardPile = state.discardPile
        self.allHands = state.hands
        self.allFaceUpIndices = state.faceUpIndices
        self.goingOutSeat = state.goingOutSeat
        var incomingBacks = state.seatCardBacks ?? Array(repeating: "cardBackRed", count: state.seats.count)
        if incomingBacks.count < state.seats.count {
            incomingBacks.append(contentsOf: Array(repeating: "cardBackRed", count: state.seats.count - incomingBacks.count))
        }
        self.seatCardBacks = incomingBacks

        // Joining phase: unclaimed seats remain
        if state.seats.contains(Self.unclaimedSeat) {
            self.isJoiningPhase = true
            self.pendingJoinState = state
            let emptySeatCount = state.seats.filter { $0 == Self.unclaimedSeat }.count

            if let seatIndex = state.seats.firstIndex(of: localParticipantID) {
                // User already has a seat — set up the board
                self.mySeatIndex = seatIndex
                self.playerHand = state.hands[seatIndex]
                self.playerFaceUpIndices = state.faceUpIndices[seatIndex]
            } else if emptySeatCount == 1 {
                // User hasn't joined and there is exactly one seat left
                Task { @MainActor in
                    self.joinGame(shouldBroadcast: false)
                }
                return
            }

            // user already joined, OR user hasn't joined but seats != 1
            self.phase = .idlePhase
            return
            
        } // else...

        // The game has started!
        self.isJoiningPhase = false

        guard let seatIndex = state.seats.firstIndex(of: localParticipantID) else {
            self.playerHand = []
            self.isSpectating = true
            self.phase = .idlePhase
            return
        }

        self.mySeatIndex = seatIndex
        let isMyTurn = (state.currentSeatIndex == seatIndex)
        self.playerHand = state.hands[seatIndex]
        let playerBeforeUser = (seatIndex - 1 + state.seats.count) % state.seats.count
        self.animatingOpponentSeat = playerBeforeUser

        if isMyTurn,
           let data = UserDefaults.standard.data(forKey: "midTurn_\(state.sessionID.uuidString)"),
           let stashedHoveringCard = try? JSONDecoder().decode(Card.self, from: data) {
            // Mid-turn recovery
            self.isSpectating = false
            self.hoveringCard = stashedHoveringCard
            self.playerFaceUpIndices = state.faceUpIndices[seatIndex]
            self.opponentHand = state.hands[playerBeforeUser]
            var opponentFaceUp = state.faceUpIndices[playerBeforeUser]
            if let idx = state.lastPlayerIndexReplaced { opponentFaceUp.insert(idx) }
            self.opponentFaceUpIndices = opponentFaceUp
            if let topDeckCard = deck.last,
               stashedHoveringCard.id == topDeckCard.id {
                deck.removeLast()
            } else {
                discardPile.removeLast()
            }
            phase = .placementPhase

        } else if isMyTurn {
            self.isSpectating = false
            self.playerFaceUpIndices = state.faceUpIndices[seatIndex]
            self.opponentFaceUpIndices = state.faceUpIndices[playerBeforeUser] // pre-turn for animation
            let hasVisualsToAnimate = applyOpponentTurnVisualsV2(state: state, previousSeat: playerBeforeUser)
            if hasVisualsToAnimate {
                phase = .animationPhase
            } else {
                if goingOutSeat == mySeatIndex {
                    resolveGameEndV2()
                } else {
                    phase = .drawPhase
                }
            }

        } else {
            self.isSpectating = true
            let lastMover = (state.currentSeatIndex - 1 + state.seats.count) % state.seats.count
            if seatIndex == lastMover {
                var myFaceUp = state.faceUpIndices[seatIndex]
                if let idx = state.lastPlayerIndexReplaced { myFaceUp.insert(idx) }
                self.playerFaceUpIndices = myFaceUp
            } else {
                self.playerFaceUpIndices = state.faceUpIndices[seatIndex]
            }
            self.opponentFaceUpIndices = state.faceUpIndices[playerBeforeUser]

            if let goSeat = goingOutSeat, state.currentSeatIndex == goSeat {
                resolveGameEndV2()
            } else {
                let lastPlayerSeat = (state.currentSeatIndex - 1 + state.seats.count) % state.seats.count
                self.animatingOpponentSeat = lastPlayerSeat
                self.opponentFaceUpIndices = state.faceUpIndices[lastPlayerSeat]
                let hasVisualsToAnimate = applyOpponentTurnVisualsV2(state: state, previousSeat: lastPlayerSeat)
                phase = .idlePhase
                isAnimatingOpponentTurn = hasVisualsToAnimate
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
        self.drewFromDeck = false
        self.hoveringCard = nil
        self.indexReplaced = nil
        self.playerHasWon = false
        self.opponentHasWon = false
        self.isGameOver = false
        self.hasPerformedInitialLoad = false
        self.turnNumber = 0
        self.playerFaceUpIndices = []
        self.opponentFaceUpIndices = []
        self.opponentDepartingFromIndex = nil
        self.playerScore = 0
        self.opponentScore = 0
        self.preTurnFaceUpIndices = []
        self.seats = []
        self.mySeatIndex = 0
        self.allHands = []
        self.allFaceUpIndices = []
        self.animatingOpponentSeat = 0
        self.isSpectating = false
        self.isAnimatingOpponentTurn = false
        self.isSinglePlayer = true
        self.isJoiningPhase = false
        self.isSettlingAfterJoin = false
        self.joinWasOverwritten = false
        self.pendingJoinState = nil
        self.goingOutSeat = nil
        self.opponentCardBack = "cardBackRed"
        self.seatCardBacks = []
    }

    private func applyOpponentTurnVisuals(state: GolfGameState) -> Bool {
        guard state.turnNumber > 0 else {
            self.opponentHand = state.senderHand //first turn! simple init, no turn to show
            return false
        }
        self.drewFromDeck = state.senderDrewFromDeck
        var cardTheyDrew: Card

        if let replacedIndex = state.indexSenderReplaced { //the opponent replaced a card
            self.indexReplaced = replacedIndex

            // The state contains the hand AFTER the swap. We need to undo it so we can animate it forward.
            // After their turn: hand[replacedIndex] = drawnCard, and the old card is on top of discardPile.
            var opponentsHandPreAnimation = state.senderHand
            let cardTheyDiscarded = discardPile.popLast()! // the old card they replaced (top of discard)
            cardTheyDrew = opponentsHandPreAnimation[replacedIndex] // the new card they placed
            // Undo the swap: put the old card back, return the drawn card to its source
            opponentsHandPreAnimation[replacedIndex] = cardTheyDiscarded
            opponentHand = opponentsHandPreAnimation

        } else { //they just discarded from deck
            self.indexReplaced = nil
            cardTheyDrew = discardPile.popLast()!
            opponentHand = state.senderHand
        }

        if drewFromDeck {
            deck.append(cardTheyDrew)
        } else {
            discardPile.append(cardTheyDrew)
        }

        return true
    }

    private func applyOpponentTurnVisualsV2(state: GolfV2GameState, previousSeat: Int) -> Bool {
        guard state.turnNumber > 0 else {
            self.opponentHand = state.hands[previousSeat]
            return false
        }
        self.drewFromDeck = state.lastPlayerDrewFromDeck
        var cardTheyDrew: Card

        if let replacedIndex = state.lastPlayerIndexReplaced {
            self.indexReplaced = replacedIndex
            var opponentsHandPreAnimation = state.hands[previousSeat]
            let cardTheyDiscarded = discardPile.popLast()!
            cardTheyDrew = opponentsHandPreAnimation[replacedIndex]
            opponentsHandPreAnimation[replacedIndex] = cardTheyDiscarded
            opponentHand = opponentsHandPreAnimation
        } else {
            self.indexReplaced = nil
            cardTheyDrew = discardPile.popLast()!
            opponentHand = state.hands[previousSeat]
        }

        if drewFromDeck {
            deck.append(cardTheyDrew)
        } else {
            discardPile.append(cardTheyDrew)
        }

        return true
    }

    /// Standard 6-card golf scoring. Column pairs (0,3), (1,4), (2,5) cancel to 0 if ranks match.
    /// King=0, Ace=1, 2-10=face value, Jack/Queen=10. Lowest score wins.
    static func calculateScore(hand: [Card]) -> Int {
        let columnPairs = [(0, 3), (1, 4), (2, 5)]
        var score = 0
        var cancelledIndices: Set<Int> = []

        for (top, bottom) in columnPairs {
            if hand[top].rank == hand[bottom].rank {
                cancelledIndices.insert(top)
                cancelledIndices.insert(bottom)
            }
        }

        for (index, card) in hand.enumerated() {
            if cancelledIndices.contains(index) { continue }
            score += GolfManager.cardValue(card)
        }
        return score
    }

    private static func cardValue(_ card: Card) -> Int {
        switch card.rank {
        case .king:  return 0
        case .ace:   return 1
        case .jack, .queen: return 10
        default:     return card.rank.rawValue + 1 // rawValue is 0-indexed: two=1 → value 2, etc.
        }
    }

    private func resolveGameEnd(playerLastToMove: Bool) {
        playerFaceUpIndices = Set(0..<6)
        opponentFaceUpIndices = Set(0..<6)
        playerScore = GolfManager.calculateScore(hand: playerHand)
        opponentScore = GolfManager.calculateScore(hand: opponentHand)
        if playerLastToMove {
            playerHasWon = playerScore <= opponentScore
        } else {
            playerHasWon = playerScore < opponentScore
        }
        opponentHasWon = !playerHasWon
        SoundManager.instance.playGameEnd(didWin: playerHasWon)
        if playerHasWon { recordWinOnce() }
        phase = .gameEndPhase
        isGameOver = true
    }

    private func resolveGameEndV2() {
        playerFaceUpIndices = Set(0..<6)
        opponentFaceUpIndices = Set(0..<6)
        for i in 0..<allFaceUpIndices.count {
            allFaceUpIndices[i] = Set(0..<6)
        }

        allHands[mySeatIndex] = playerHand
        playerScore = GolfManager.calculateScore(hand: playerHand)

        let otherScores = allHands.enumerated()
            .filter { $0.offset != mySeatIndex }
            .map { GolfManager.calculateScore(hand: $0.element) }
        let bestOtherScore = otherScores.min() ?? Int.max
        opponentScore = bestOtherScore

        if mySeatIndex == goingOutSeat {
            playerHasWon = playerScore < bestOtherScore
        } else {
            playerHasWon = playerScore <= bestOtherScore
        }
        opponentHasWon = !playerHasWon

        SoundManager.instance.playGameEnd(didWin: playerHasWon)
        if playerHasWon { recordWinOnce() }
        phase = .gameEndPhase
        isGameOver = true
    }

    private func recordWinOnce() {
        guard let sID = sessionID else { return }
        WinTracker.shared.recordWinOnce(for: "Golf", sessionID: sID)
        //GameCenterManager.shared.reportWin(firstWin: .firstWinGolf)
    }

    func createNewGameState(seats: [UUID]) -> Data? {
        let newSessionID = UUID()
        let playerCount = seats.count
        
        let decksNeeded = max(1, (playerCount - 1) / 5 + 1)
        var newDeck = (0..<decksNeeded)
            .flatMap { _ in Deck().cards }
            .shuffled()

        var newHands: [[Card]] = Array(repeating: [], count: playerCount)
        for _ in 0..<6 {
            for i in 0..<playerCount {
                newHands[i].append(newDeck.popLast()!)
            }
        }
        var newDiscardPile: [Card] = []
        newDiscardPile.append(newDeck.popLast()!)

        // Randomly choose 2 cards to start face up for each player
        let allIndices = Array(0..<6)
        var newFaceUpIndices: [Set<Int>] = []
        for _ in 0..<playerCount {
            newFaceUpIndices.append(Set(allIndices.shuffled().prefix(2)))
        }

        let myCardBack = CardBackSelection.shared.selectedName

        if seats.count == 2 { //1v1 game mode, create legacy game state
            let initialState = GolfGameState(
                sessionID: newSessionID,
                deck: newDeck,
                discardPile: newDiscardPile,
                senderHand: newHands[0],
                receiverHand: newHands[1],
                senderDrewFromDeck: false,
                indexSenderReplaced: nil,
                turnNumber: 0,
                senderFaceUpIndices: newFaceUpIndices[0],
                receiverFaceUpIndices: newFaceUpIndices[1],
                senderCardBack: myCardBack)
            self.isSinglePlayer = true
            return try? JSONEncoder().encode(initialState)

        } else { //we have a groupchat
            // Only seat 0 belongs to the creator; remaining seats are unclaimed until players join
            var seatList = [seats[0]]
            for _ in 1..<playerCount {
                seatList.append(Self.unclaimedSeat)
            }

            var initialBacks = Array(repeating: "cardBackRed", count: playerCount)
            initialBacks[0] = myCardBack

            let initialState = GolfV2GameState(
                sessionID: newSessionID,
                deck: newDeck,
                discardPile: newDiscardPile,
                seats: seatList,
                hands: newHands,
                currentSeatIndex: 1 % playerCount,
                turnNumber: 0,
                lastPlayerDrewFromDeck: false,
                lastPlayerIndexReplaced: nil,
                faceUpIndices: newFaceUpIndices,
                goingOutSeat: nil,
                seatCardBacks: initialBacks)
            self.isSinglePlayer = false
            return try? JSONEncoder().encode(initialState)
        }
    }

    func joinGame(shouldBroadcast: Bool = true) {
        guard let state = pendingJoinState,
              let lpID = localParticipantID,
              let joinData = getJoinData(state: state, localParticipantID: lpID) else { return }

        joinWasOverwritten = false
        pendingJoinState = nil
        UserDefaults.standard.set(joinData, forKey: "golf_joined_\(state.sessionID.uuidString)")
        if shouldBroadcast {
            onJoinCompleted?(joinData, .golf)
        }
        loadState(from: joinData, isPlayersTurn: false, localParticipantID: lpID, isSinglePlayer: false, conversationID: "")
        
        if isJoiningPhase {
            isSettlingAfterJoin = true
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s
                self.isSettlingAfterJoin = false
            }
        }
    }
    
    func getJoinData(state: GolfV2GameState, localParticipantID: UUID) -> Data? {
        guard !state.seats.contains(localParticipantID),
              let openIndex = state.seats.firstIndex(of: Self.unclaimedSeat) else { return nil }

        var updatedSeats = state.seats
        updatedSeats[openIndex] = localParticipantID

        let isLobbyNowFull = !updatedSeats.contains(Self.unclaimedSeat)
        let nextSeatIndex = isLobbyNowFull ? updatedSeats.firstIndex(of: localParticipantID)! : state.currentSeatIndex

        var updatedBacks = state.seatCardBacks ?? Array(repeating: "cardBackRed", count: state.seats.count)
        if updatedBacks.count < updatedSeats.count {
            updatedBacks.append(contentsOf: Array(repeating: "cardBackRed", count: updatedSeats.count - updatedBacks.count))
        }
        updatedBacks[openIndex] = CardBackSelection.shared.selectedName

        let updatedState = GolfV2GameState(
            sessionID: state.sessionID,
            deck: state.deck,
            discardPile: state.discardPile,
            seats: updatedSeats,
            hands: state.hands,
            currentSeatIndex: nextSeatIndex,
            turnNumber: state.turnNumber + 1,
            lastPlayerDrewFromDeck: false,
            lastPlayerIndexReplaced: nil,
            faceUpIndices: state.faceUpIndices,
            goingOutSeat: nil,
            seatCardBacks: updatedBacks)

        return try? JSONEncoder().encode(updatedState)
    }

    private func sendLegacyGameState() {
        let currentGameState = GolfGameState(
            sessionID: self.sessionID!,
            deck: self.deck,
            discardPile: self.discardPile,
            senderHand: self.playerHand,
            receiverHand: self.opponentHand,
            senderDrewFromDeck: self.drewFromDeck,
            indexSenderReplaced: self.indexReplaced,
            turnNumber: self.turnNumber + 1,
            senderFaceUpIndices: self.preTurnFaceUpIndices,
            receiverFaceUpIndices: self.opponentFaceUpIndices,
            senderCardBack: CardBackSelection.shared.selectedName
        )

        guard let stateData = try? JSONEncoder().encode(currentGameState) else {
            print("Error: Failed to encode GolfGameState into Data.")
            return
        }

        self.turnNumber += 1
        self.onTurnCompleted?(stateData, .golf) //send data to MessagesViewController
    }

    private func sendV2GameState() {
        allHands[mySeatIndex] = playerHand
        let previousSeat = (mySeatIndex - 1 + seats.count) % seats.count
        if turnNumber > 0 {
            allHands[previousSeat] = opponentHand
            allFaceUpIndices[previousSeat] = opponentFaceUpIndices
        }

        allFaceUpIndices[mySeatIndex] = preTurnFaceUpIndices

        let nextSeat = (mySeatIndex + 1) % seats.count

        var outgoingBacks = seatCardBacks
        if outgoingBacks.count < seats.count {
            outgoingBacks.append(contentsOf: Array(repeating: "cardBackRed", count: seats.count - outgoingBacks.count))
        }
        if outgoingBacks.indices.contains(mySeatIndex) {
            outgoingBacks[mySeatIndex] = CardBackSelection.shared.selectedName
        }

        let currentGameState = GolfV2GameState(
            sessionID: self.sessionID!,
            deck: self.deck,
            discardPile: self.discardPile,
            seats: self.seats,
            hands: self.allHands,
            currentSeatIndex: nextSeat,
            turnNumber: self.turnNumber + 1,
            lastPlayerDrewFromDeck: self.drewFromDeck,
            lastPlayerIndexReplaced: self.indexReplaced,
            faceUpIndices: self.allFaceUpIndices,
            goingOutSeat: self.goingOutSeat,
            seatCardBacks: outgoingBacks
        )

        guard let stateData = try? JSONEncoder().encode(currentGameState) else {
            print("Error: Failed to encode GolfV2GameState into Data.")
            return
        }

        self.turnNumber += 1
        // Mark our seat as the one who just played so the deck immediately reflects the next player's back.
        self.seatCardBacks = outgoingBacks
        self.animatingOpponentSeat = mySeatIndex
        self.onTurnCompleted?(stateData, .golf)
    }

}
