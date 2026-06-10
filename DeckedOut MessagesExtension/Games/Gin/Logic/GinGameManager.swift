//
//  GinGameManager.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 11/26/25.
//

import Foundation

enum GinRoundWinType: String, Codable {
    case gin
    case knock
    case undercut
}

enum GinRoundWinner: String, Codable {
    case sender
    case receiver
}

// V1: Legacy 2-player game snapshot
struct GinRummyGameState: Codable, BasicGameState {
    let sessionID: UUID
    let deck: [Card]
    let discardPile: [Card]
    let senderHand: [Card]
    let receiverHand: [Card]
    let senderDrewFromDeck: Bool
    let indexSenderDrewTo: Int?
    let indexSenderDiscardedFrom: Int?
    let turnNumber: Int
    let senderCardBack: String? //the card-back the sender has equipped; optional for backward compat
    let roundWinner: GinRoundWinner? //explicit winner metadata for non-gin round endings
    let roundWinType: GinRoundWinType? //distinguishes gin/knock/undercut outcomes
}

// V2: Seat-based groupchat multiplayer game snapshot
struct GinRummyV2GameState: Codable, V2GameState {
    let sessionID: UUID
    let deck: [Card]
    let discardPile: [Card]
    let seats: [UUID]
    let hands: [[Card]]
    let currentSeatIndex: Int
    let turnNumber: Int
    let lastPlayerDrewFromDeck: Bool
    let lastPlayerIndexDrewTo: Int?
    let lastPlayerIndexDiscardedFrom: Int?
    let seatCardBacks: [String]? //parallel to seats; optional for backward compat
}

// MARK: The Game Engine
class GinRummyManager: ObservableObject, GameEngine, GroupChatCapable {
    static let shared = GinRummyManager()
    static let unclaimedSeat = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    
    @Published var extensionWidth: CGFloat = 375
    @Published var sessionID: UUID? = nil
    @Published var playerHand: [Card] = []
    @Published var opponentHand: [Card] = []
    @Published var deck: [Card] = []
    @Published var discardPile: [Card] = []
    @Published var phase: TurnPhase = .animationPhase //stays local
    @Published var opponentDrewFromDeck: Bool = false
    @Published var indexDrawnTo: Int? = nil
    @Published var indexDiscardedFrom: Int? = nil
    var drawnCard: Card? = nil
    @Published var playerHasWon: Bool = false //stays local
    @Published var opponentHasWon: Bool = false //stays local
    @Published var isGameOver: Bool = false //stays local
    @Published var turnNumber: Int = 0

    // Knock state is only used in legacy 1v1 10-card gin.
    private var shouldKnockOnDiscard: Bool = false
    private var roundWinner: GinRoundWinner? = nil
    private var roundWinType: GinRoundWinType? = nil

    var currentRoundWinType: GinRoundWinType? {
        roundWinType
    }

    var shouldShowKnockRules: Bool {
        isSinglePlayer && handSize == 10
    }
    
    var hasPerformedInitialLoad: Bool = false //stays local. this is just for the 0.5 delay in game view when you open a message
    var handSize: Int = 7 //configurable from the menu (7 or 10)
    var isSinglePlayer: Bool = true

    // Card-back equipped by each player (sent in the message payload)
    @Published var opponentCardBack: String = "cardBackRed" //v1: the single opponent's equipped back
    @Published var seatCardBacks: [String] = [] //v2: parallel to `seats`; updated each turn

    // Multiplayer (V2) properties
    var seats: [UUID] = []
    var mySeatIndex: Int = 0
    @Published var allHands: [[Card]] = []
    var animatingOpponentSeat: Int = 0
    var isSpectating: Bool = false
    @Published var isAnimatingOpponentTurn: Bool = false
    @Published var isJoiningPhase: Bool = false
    @Published var isSettlingAfterJoin: Bool = false
    @Published var joinWasOverwritten: Bool = false
    var pendingJoinState: GinRummyV2GameState? = nil
    var localParticipantID: UUID? = nil

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

    private init() {} // values are already initialized here ^

    // The View Controller will listen to these to know when to send the message
    var onTurnCompleted: ((Data, GameType) -> Void)?
    var onJoinCompleted: ((Data, GameType) -> Void)?
    
    enum TurnPhase {
        case animationPhase // Animating the opponents turn before your own
        case drawPhase      // Waiting for user to pick from Deck or Discard
        case discardPhase   // Waiting for user to drag a card to discard pile
        case idlePhase      // Opponent's turn
        case gameEndPhase   // Only unlocked upon winning
    }
    
    
    func drawFromDeck() {
        guard phase == .drawPhase, !deck.isEmpty else { return }
        let card = deck.popLast()!
        playerHand.append(card)
        drawnCard = card
        indexDrawnTo = playerHand.count - 1
        opponentDrewFromDeck = true
        phase = .discardPhase
    }

    func drawFromDiscard() {
        guard phase == .drawPhase, !discardPile.isEmpty else { return }
        let card = discardPile.popLast()!
        playerHand.append(card)
        drawnCard = card
        indexDrawnTo = playerHand.count - 1
        opponentDrewFromDeck = false
        phase = .discardPhase
    }
    
    func discardCard(card: Card) { //possible room for refactoring/removing discardCard
        guard phase == .discardPhase, let index = playerHand.firstIndex(of: card) else { return }
        // Capture and clear the local knock intent at discard-time so one tap only applies to one discard.
        let shouldEvaluateKnock = shouldKnockOnDiscard
        shouldKnockOnDiscard = false

        if let drawn = drawnCard, let drawnIndex = playerHand.firstIndex(of: drawn) {
            indexDrawnTo = drawnIndex
        }
        indexDiscardedFrom = index
        playerHand.remove(at: index) //we could also use indexDiscardedFrom...
        discardPile.append(card)
        SoundManager.instance.playCardSlap()
        HapticManager.instance.playCardSlap()

        roundWinner = nil
        roundWinType = nil

        playerHasWon = GinRummyValidator.canMeldAllCards(hand: playerHand)
        if playerHasWon {
            isGameOver = true
            roundWinner = .sender
            roundWinType = .gin
            SoundManager.instance.playGameEnd(didWin: true)
            phase = .gameEndPhase
            WinTracker.shared.incrementWins(for: "Gin Rummy")
        } else if shouldEvaluateKnock && canPlayerKnock {
            resolveKnockRoundForLegacySender()
        } else {
            isGameOver = false
            phase = .idlePhase
        }
        sendGameStateSwitch()
    }

    var canPlayerKnock: Bool {
        guard isSinglePlayer else { return false }
        guard handSize == 10 else { return false }
        guard phase == .discardPhase else { return false }

        // Before the discard, the hand has 11 cards. Show the button when any legal
        // discard would leave a non-gin hand with 10 or less deadwood.
        if playerHand.count == handSize + 1 {
            return playerHand.contains { candidate in
                var postDiscardHand = playerHand
                guard let index = postDiscardHand.firstIndex(of: candidate) else { return false }
                postDiscardHand.remove(at: index)
                return canKnock(afterDiscarding: postDiscardHand)
            }
        }

        return canKnock(afterDiscarding: playerHand)
    }

    func requestKnock() {
        guard canPlayerKnock else {
            HapticManager.instance.playErrorFeedback()
            return
        }
        shouldKnockOnDiscard = true
    }

    func sortPlayerHand(sortState: Int) {
        // sortState: 0 = unsorted, 1 = sorted ascending, 2 = sorted descending
        if sortState == 0 {
            // Just play a sound/haptic, no actual sorting
            HapticManager.instance.playCardReorder()
            return
        }
        
        let sortedHand = playerHand.sorted { card1, card2 in
            // First sort by suit (spades=0, hearts=1, clubs=2, diamonds=3)
            if card1.suit.rawValue != card2.suit.rawValue {
                let suitComparison = card1.suit.rawValue < card2.suit.rawValue
                return sortState == 1 ? suitComparison : !suitComparison
            }
            // Then sort by rank (ace=0 lowest, king=12 highest)
            let rankComparison = card1.rank.rawValue < card2.rank.rawValue
            return sortState == 1 ? rankComparison : !rankComparison
        }
        
        playerHand = sortedHand
        HapticManager.instance.playCardReorder()
    }

    private func resolveKnockRoundForLegacySender() {
        guard let outcome = GinRummyValidator.evaluateKnock(knockerHand: playerHand, defenderHand: opponentHand) else {
            isGameOver = false
            phase = .idlePhase
            return
        }

        if outcome.isUndercut {
            playerHasWon = false
            opponentHasWon = true
            roundWinner = .receiver
            roundWinType = .undercut
        } else {
            playerHasWon = true
            opponentHasWon = false
            roundWinner = .sender
            roundWinType = .knock
            WinTracker.shared.incrementWins(for: "Gin Rummy")
        }

        isGameOver = true
        SoundManager.instance.playGameEnd(didWin: playerHasWon)
        phase = .gameEndPhase
    }

    private func canKnock(afterDiscarding hand: [Card]) -> Bool {
        guard hand.count == handSize else { return false }
        guard !GinRummyValidator.canMeldAllCards(hand: hand) else { return false }
        return GinRummyValidator.minimumDeadwoodPoints(hand: hand) <= 10
    }
    
    func opponentDrawFromDeck() {
        guard phase == .animationPhase || isAnimatingOpponentTurn,
              !deck.isEmpty,
              let drawIndex = indexDrawnTo,
              drawIndex <= opponentHand.count else {
            return
        }
        let card = deck.popLast()!
        opponentHand.insert(card, at: drawIndex)
    }

    func opponentDrawFromDiscard() {
        guard phase == .animationPhase || isAnimatingOpponentTurn,
              !discardPile.isEmpty,
              let drawIndex = indexDrawnTo,
              drawIndex <= opponentHand.count else {
            return
        }
        let card = discardPile.popLast()!
        opponentHand.insert(card, at: drawIndex)
    }

    func opponentDiscardCard(card: Card) {
        guard phase == .animationPhase || isAnimatingOpponentTurn,
              let discardIndex = indexDiscardedFrom,
              discardIndex < opponentHand.count else {
            return
        }
        opponentHand.remove(at: discardIndex)
        discardPile.append(card)
        SoundManager.instance.playCardSlap()
        HapticManager.instance.playCardSlap()
        opponentHasWon = GinRummyValidator.canMeldAllCards(hand: opponentHand)
        if opponentHasWon {
            isGameOver = true
            roundWinner = .sender
            roundWinType = .gin
            SoundManager.instance.playGameEnd(didWin: false)
            isAnimatingOpponentTurn = false
            phase = .gameEndPhase
        } else if isAnimatingOpponentTurn {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.isAnimatingOpponentTurn = false
            }
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
        guard phase == .discardPhase, let sID = sessionID else { return } //only save if the user is currently in the middle of a turn
        
        if let encoded = try? JSONEncoder().encode(playerHand) {
            UserDefaults.standard.set(encoded, forKey: "midTurn_\(sID.uuidString)")
        }
    }
    
    func clearMidTurnState(conversationID: String) {
        guard let sID = sessionID else { return }
        UserDefaults.standard.removeObject(forKey: "midTurn_\(sID.uuidString)")
    }
    
    func loadState(from data: Data, isPlayersTurn: Bool, localParticipantID: UUID = UUID(), isSinglePlayer: Bool = true, conversationID: String, isExplicitChange: Bool = false) {
        if isSinglePlayer == false, let v2State = try? JSONDecoder().decode(GinRummyV2GameState.self, from: data) {
            loadV2State(state: v2State, localParticipantID: localParticipantID, conversationID: conversationID, isExplicitChange: isExplicitChange)
        } else if let legacyState = try? JSONDecoder().decode(GinRummyGameState.self, from: data) {
            loadLegacyState(state: legacyState, isPlayersTurn: isPlayersTurn, conversationID: conversationID, isExplicitChange: isExplicitChange)
        } else {
            print("Error: Failed to decode GinRummyGameState from data.")
        }
    }

    private func loadLegacyState(state: GinRummyGameState, isPlayersTurn: Bool, conversationID: String, isExplicitChange: Bool) {
        let isInitialLoad = (self.sessionID == nil)
        let isSameSession = (self.sessionID == state.sessionID)
        let isNewTurn = state.turnNumber > self.turnNumber
        
        guard isInitialLoad || (isSameSession && isNewTurn) || isExplicitChange else { return }
        
        if isExplicitChange {
            resetToInit()
        }
        
        self.isSinglePlayer = true
        self.sessionID = state.sessionID
        self.turnNumber = state.turnNumber
        self.deck = state.deck
        self.discardPile = state.discardPile
        self.roundWinner = state.roundWinner
        self.roundWinType = state.roundWinType
        self.shouldKnockOnDiscard = false
        // The sender of this message is the opponent we're about to play against.
        if isPlayersTurn, let sentBack = state.senderCardBack {
            self.opponentCardBack = sentBack
        }

        if isPlayersTurn, //does not check if this is the same game session!! just the same conversation!!
           let data = UserDefaults.standard.data(forKey: "midTurn_\(state.sessionID.uuidString)"),
           let stashedHand = try? JSONDecoder().decode([Card].self, from: data) { //the user is mid-turn...
            self.playerHand = stashedHand
            self.opponentHand = state.senderHand
            if let topDeckCard = deck.last,
               stashedHand.contains(where: { $0.id == topDeckCard.id }) { // the user previously drew from the deck
                deck.removeLast()
            } else { //the user drew from the discard pile instead
                discardPile.removeLast()
            }
            phase = .discardPhase
            
        } else if isPlayersTurn { //the user is beginning their turn...
            self.playerHand = state.receiverHand
            let hasVisualsToAnimate = applyOpponentTurnVisuals(state: state)
            if hasVisualsToAnimate {//it is not the first turn...
                phase = .animationPhase
            } else { //it is the first turn...
                hydrateLegacyWinnerFlagsFromRoundResult(isPlayersTurn: isPlayersTurn)
                if !isGameOver {
                    checkWin() //this would be a first turn win. chance of that is 1 in 308,984! (refactor to prevent this edge case in later update)
                }
                if isGameOver {
                    phase = .gameEndPhase
                    SoundManager.instance.playGameEnd(didWin: self.playerHasWon)
                } else {
                    phase = .drawPhase
                }
            }
            
        } else { //it is not the players turn...
            self.playerHand = state.senderHand
            self.opponentHand = state.receiverHand
            hydrateLegacyWinnerFlagsFromRoundResult(isPlayersTurn: isPlayersTurn)
            if !isGameOver {
                playerHasWon = GinRummyValidator.canMeldAllCards(hand: self.playerHand)
                if playerHasWon {
                    roundWinner = .sender
                    roundWinType = .gin
                    isGameOver = true
                }
            }
            if isGameOver {
                phase = .gameEndPhase
                SoundManager.instance.playGameEnd(didWin: self.playerHasWon)
            } else {
                // only enter animation phase if it's our turn to watch the opponent move
                phase = .idlePhase
            }
        }
    }

    private func hydrateLegacyWinnerFlagsFromRoundResult(isPlayersTurn: Bool) {
        guard let winner = roundWinner else {
            playerHasWon = false
            opponentHasWon = false
            isGameOver = false
            return
        }

        // In legacy state, sender == message author and receiver == viewer.
        // `isPlayersTurn` means the local player is receiver for this update.
        let localIsReceiver = isPlayersTurn
        let localWon: Bool
        if localIsReceiver {
            localWon = (winner == .receiver)
        } else {
            localWon = (winner == .sender)
        }

        playerHasWon = localWon
        opponentHasWon = !localWon
        isGameOver = true
    }

    private func loadV2State(state: GinRummyV2GameState, localParticipantID: UUID, conversationID: String, isExplicitChange: Bool) {
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
            let joinRecord = "gin_joined_\(state.sessionID.uuidString)"
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
        // Take the latest per-seat card backs from the message, defaulting any missing entries.
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

        // The player inserted their localParticipantIdentifier during the join phase
        guard let seatIndex = state.seats.firstIndex(of: localParticipantID) else { // else the user hasnt joined this game. (Joined the groupchat after start?)
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
           let stashedHand = try? JSONDecoder().decode([Card].self, from: data) { //the user is mid-turn...
            self.isSpectating = false
            self.opponentHand = state.hands[playerBeforeUser]
            self.playerHand = stashedHand
            if let topDeckCard = deck.last,
               stashedHand.contains(where: { $0.id == topDeckCard.id }) {
                deck.removeLast()
            } else {
                discardPile.removeLast()
            }
            phase = .discardPhase

        } else if isMyTurn {
            self.isSpectating = false
            let hasVisualsToAnimate = applyOpponentTurnVisualsV2(state: state, previousSeat: playerBeforeUser)
            if hasVisualsToAnimate {
                phase = .animationPhase
            } else { //it is the first turn
                checkWin()
                if isGameOver {
                    phase = .gameEndPhase
                    SoundManager.instance.playGameEnd(didWin: self.playerHasWon)
                } else {
                    phase = .drawPhase
                }
            }

        } else { //it is not the current users turn
            self.isSpectating = true
            playerHasWon = GinRummyValidator.canMeldAllCards(hand: self.playerHand)
            if playerHasWon {
                phase = .gameEndPhase
                SoundManager.instance.playGameEnd(didWin: true)
            } else {
                let lastPlayerSeat = (state.currentSeatIndex - 1 + state.seats.count) % state.seats.count
                self.animatingOpponentSeat = lastPlayerSeat
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
        self.opponentDrewFromDeck = false
        self.indexDrawnTo = nil
        self.indexDiscardedFrom = nil
        self.drawnCard = nil
        self.shouldKnockOnDiscard = false
        self.playerHasWon = false
        self.opponentHasWon = false
        self.isGameOver = false
        self.roundWinner = nil
        self.roundWinType = nil
        self.hasPerformedInitialLoad = false
        self.turnNumber = 0
        self.seats = []
        self.mySeatIndex = 0
        self.allHands = []
        self.animatingOpponentSeat = 0
        self.isSpectating = false
        self.isAnimatingOpponentTurn = false
        self.isSinglePlayer = true
        self.isJoiningPhase = false
        self.isSettlingAfterJoin = false
        self.joinWasOverwritten = false
        self.pendingJoinState = nil
        self.opponentCardBack = "cardBackRed"
        self.seatCardBacks = []
    }
    
    private func applyOpponentTurnVisuals(state: GinRummyGameState) -> Bool {
        guard let discardedIndex = state.indexSenderDiscardedFrom,
              let drawnIndex = state.indexSenderDrewTo else {
            self.opponentHand = state.senderHand //first turn! simple init, no turn to show
            return false
        }
        
        self.opponentDrewFromDeck = state.senderDrewFromDeck
        indexDrawnTo = drawnIndex
        indexDiscardedFrom = discardedIndex
        
        var opponentsHandPreAnimation = state.senderHand
        let cardTheyDiscarded = discardPile.popLast()! //we will animate it back later...
        opponentsHandPreAnimation.insert(cardTheyDiscarded, at: discardedIndex)
        let cardToReturn = opponentsHandPreAnimation.remove(at: drawnIndex)
        if opponentDrewFromDeck {
            deck.append(cardToReturn)
        } else {
            discardPile.append(cardToReturn)
        }
        opponentHand = opponentsHandPreAnimation
        
        return true
    }

    private func applyOpponentTurnVisualsV2(state: GinRummyV2GameState, previousSeat: Int) -> Bool {
        guard let discardedIndex = state.lastPlayerIndexDiscardedFrom,
              let drawnIndex = state.lastPlayerIndexDrewTo else {
            self.opponentHand = state.hands[previousSeat] //first turn! simple init, no turn to show
            return false
        }

        self.opponentDrewFromDeck = state.lastPlayerDrewFromDeck
        indexDrawnTo = drawnIndex
        indexDiscardedFrom = discardedIndex

        var opponentsHandPreAnimation = state.hands[previousSeat]
        let cardTheyDiscarded = discardPile.popLast()!
        opponentsHandPreAnimation.insert(cardTheyDiscarded, at: discardedIndex)
        let cardToReturn = opponentsHandPreAnimation.remove(at: drawnIndex)
        if opponentDrewFromDeck {
            deck.append(cardToReturn)
        } else {
            discardPile.append(cardToReturn)
        }
        opponentHand = opponentsHandPreAnimation

        return true
    }
    
    func checkWin() { //set for deprecation when we disallow first turn wins
        roundWinner = nil
        roundWinType = nil
        playerHasWon = GinRummyValidator.canMeldAllCards(hand: playerHand)
        opponentHasWon = GinRummyValidator.canMeldAllCards(hand: opponentHand)
        if playerHasWon {
            roundWinner = .sender
            roundWinType = .gin
        } else if opponentHasWon {
            roundWinner = .receiver
            roundWinType = .gin
        }
        isGameOver = playerHasWon || opponentHasWon
    }
    
    func createNewGameState(seats: [UUID]) -> Data? {
        let newSessionID = UUID()
        let playerCount = seats.count

        // Scale decks dynamically: 1 deck for 1-5 players, 2 for 6-10, etc.
        let decksNeeded = max(1, (playerCount - 1) / 5 + 1)
        var newDeck = (0..<decksNeeded)
            .flatMap { _ in Deck().cards }
            .shuffled()

        var newHands: [[Card]] = Array(repeating: [], count: playerCount)
        for _ in 0..<handSize {
            for i in 0..<playerCount {
                newHands[i].append(newDeck.popLast()!)
            }
        }

        var newDiscardPile: [Card] = []
        newDiscardPile.append(newDeck.popLast()!)

        // Only seat 0 belongs to the creator; remaining seats are unclaimed until players join
        var seatList = [seats[0]]
        for _ in 1..<playerCount {
            seatList.append(Self.unclaimedSeat)
        }

        let myCardBack = CardBackSelection.shared.selectedName

        if seats.count == 2 { //1v1 game mode, create legacy game state
            let legacyState = GinRummyGameState(
                sessionID: newSessionID,
                deck: newDeck,
                discardPile: newDiscardPile,
                senderHand: newHands[0],
                receiverHand: newHands[1],
                senderDrewFromDeck: false,
                indexSenderDrewTo: nil,
                indexSenderDiscardedFrom: nil,
                turnNumber: 0,
                senderCardBack: myCardBack,
                roundWinner: nil,
                roundWinType: nil)
            self.isSinglePlayer = true
            return try? JSONEncoder().encode(legacyState)

        } else { //we have a groupchat
            // Only the creator's back is known up front; other seats default until they join.
            var initialBacks = Array(repeating: "cardBackRed", count: playerCount)
            initialBacks[0] = myCardBack
            let initialState = GinRummyV2GameState(
                sessionID: newSessionID,
                deck: newDeck,
                discardPile: newDiscardPile,
                seats: seatList,
                hands: newHands,
                currentSeatIndex: 1 % playerCount,
                turnNumber: 0,
                lastPlayerDrewFromDeck: false,
                lastPlayerIndexDrewTo: nil,
                lastPlayerIndexDiscardedFrom: nil,
                seatCardBacks: initialBacks
            )
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
        UserDefaults.standard.set(joinData, forKey: "gin_joined_\(state.sessionID.uuidString)")
        if shouldBroadcast {
            onJoinCompleted?(joinData, .ginRummy)
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
    
    func getJoinData(state: GinRummyV2GameState, localParticipantID: UUID) -> Data? {
        guard !state.seats.contains(localParticipantID),
              let openIndex = state.seats.firstIndex(of: Self.unclaimedSeat) else { return nil }

        var updatedSeats = state.seats
        updatedSeats[openIndex] = localParticipantID

        let isLobbyNowFull = !updatedSeats.contains(Self.unclaimedSeat)
        let nextSeatIndex = isLobbyNowFull ? updatedSeats.firstIndex(of: localParticipantID)! : state.currentSeatIndex

        // Carry forward known card-backs and write the joiner's into their slot.
        var updatedBacks = state.seatCardBacks ?? Array(repeating: "cardBackRed", count: state.seats.count)
        if updatedBacks.count < updatedSeats.count {
            updatedBacks.append(contentsOf: Array(repeating: "cardBackRed", count: updatedSeats.count - updatedBacks.count))
        }
        updatedBacks[openIndex] = CardBackSelection.shared.selectedName

        let updatedState = GinRummyV2GameState(
            sessionID: state.sessionID,
            deck: state.deck,
            discardPile: state.discardPile,
            seats: updatedSeats,
            hands: state.hands,
            currentSeatIndex: nextSeatIndex,
            turnNumber: state.turnNumber + 1,
            lastPlayerDrewFromDeck: false,
            lastPlayerIndexDrewTo: nil,
            lastPlayerIndexDiscardedFrom: nil,
            seatCardBacks: updatedBacks)

        return try? JSONEncoder().encode(updatedState)
    }

    func sendGameStateSwitch() {
        if deck.count == 1 { reshuffleDiscardIntoDeck() }

        if isSinglePlayer {
            sendLegacyGameState()
        } else {
            sendV2GameState()
        }
    }

    private func sendLegacyGameState() {
        let currentGameState = GinRummyGameState(
            sessionID: self.sessionID!,
            deck: self.deck,
            discardPile: self.discardPile,
            senderHand: self.playerHand,
            receiverHand: self.opponentHand,
            senderDrewFromDeck: self.opponentDrewFromDeck,
            indexSenderDrewTo: self.indexDrawnTo,
            indexSenderDiscardedFrom: self.indexDiscardedFrom,
            turnNumber: self.turnNumber + 1,
            senderCardBack: CardBackSelection.shared.selectedName,
            roundWinner: self.roundWinner,
            roundWinType: self.roundWinType
        )

        guard let stateData = try? JSONEncoder().encode(currentGameState) else {
            print("Error: Failed to encode GinRummyGameState into Data.")
            return
        }

        self.onTurnCompleted?(stateData, .ginRummy) //send data to MessagesViewController
    }

    private func sendV2GameState() {
        allHands[mySeatIndex] = playerHand
        let previousSeat = (mySeatIndex - 1 + seats.count) % seats.count
        if turnNumber > 0 {
            allHands[previousSeat] = opponentHand
        }

        let nextSeat = (mySeatIndex + 1) % seats.count

        // Preserve other seats' card-backs, set our own slot to current selection.
        var outgoingBacks = seatCardBacks
        if outgoingBacks.count < seats.count {
            outgoingBacks.append(contentsOf: Array(repeating: "cardBackRed", count: seats.count - outgoingBacks.count))
        }
        if outgoingBacks.indices.contains(mySeatIndex) {
            outgoingBacks[mySeatIndex] = CardBackSelection.shared.selectedName
        }

        let currentGameState = GinRummyV2GameState(
            sessionID: self.sessionID!,
            deck: self.deck,
            discardPile: self.discardPile,
            seats: self.seats,
            hands: self.allHands,
            currentSeatIndex: nextSeat,
            turnNumber: self.turnNumber + 1,
            lastPlayerDrewFromDeck: self.opponentDrewFromDeck,
            lastPlayerIndexDrewTo: self.indexDrawnTo,
            lastPlayerIndexDiscardedFrom: self.indexDiscardedFrom,
            seatCardBacks: outgoingBacks
        )

        guard let stateData = try? JSONEncoder().encode(currentGameState) else {
            print("Error: Failed to encode GinRummyV2GameState into Data.")
            return
        }

        self.turnNumber += 1
        // Mark our seat as the one who just played so the deck immediately reflects the next player's back.
        self.seatCardBacks = outgoingBacks
        self.animatingOpponentSeat = mySeatIndex
        self.onTurnCompleted?(stateData, .ginRummy)
    }
}
