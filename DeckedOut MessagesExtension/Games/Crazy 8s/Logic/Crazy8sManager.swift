//
//  Crazy8sManager.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 2/23/26.
//

import Foundation

// V1: Legacy 2-player game snapshot
struct Crazy8sLegacyGameState: Codable, BasicGameState {
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

// V2: Seat-based groupchat multiplayer game snapshot
struct Crazy8sV2GameState: Codable, V2GameState {
    let sessionID: UUID
    let deck: [Card]
    let discardPile: [Card]
    let seats: [UUID]
    let hands: [[Card]]
    let currentSeatIndex: Int
    let turnNumber: Int
    let cardsDrawnByLastPlayer: Int
    let lastPlayerDidDiscard: Bool
    let activeSuitOverride: Suit?
}

// MARK: The Game Engine
class Crazy8sManager: ObservableObject, GameEngine, GroupChatCapable {
    static let shared = Crazy8sManager()
    static let unclaimedSeat = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    @Published var extensionWidth: CGFloat = 375
    @Published var sessionID: UUID? = nil
    @Published var deck: [Card] = []
    @Published var discardPile: [Card] = []
    @Published var playerHand: [Card] = []
    @Published var opponentHand: [Card] = []
    @Published var cardsOpponentDrew: Int = 0
    @Published var cardsDrawnThisTurn: Int = 0 //user version that replaces above int
    @Published var userDidDiscard: Bool = false
    @Published var opponentDidDiscard: Bool = false
    @Published var activeSuitOverride: Suit?
    @Published var hiddenActiveSuitOverride: Suit? //for hiding the active suit override until after the opponents discard animation is complete
    @Published var turnNumber: Int = 0
    @Published var phase: TurnPhase = .animationPhase //stays local
    @Published var userCanDiscard: Bool = false //stays local
    @Published var userNeedsToChooseSuit: Bool = false //stays local
    @Published var playerHasWon: Bool = false //stays local
    @Published var opponentHasWon: Bool = false //stays local
    @Published var isGameOver: Bool = false //stays local
    @Published var opponentCardPendingDiscard: Card? = nil // Holds the card waiting in the wings
    @Published var opponentCardAnimatingToDiscard: Card? = nil       // The trigger the view actually watches
    @Published var opponentCardAnimatingFromDeck: Card? = nil        // The trigger for draw animations
    var hasPerformedInitialLoad: Bool = false //stays local. this is just for the 0.5 delay in game view when you open a message

    // Multiplayer (V2) properties
    var seats: [UUID] = []
    var mySeatIndex: Int = 0
    @Published var allHands: [[Card]] = []
    var isSinglePlayer: Bool = false
    var isSpectating: Bool = false
    @Published var isAnimatingOpponentTurn: Bool = false
    var animatingOpponentSeat: Int = 0
    @Published var isJoiningPhase: Bool = false
    @Published var isSettlingAfterJoin: Bool = false
    @Published var joinWasOverwritten: Bool = false
    var pendingJoinState: Crazy8sV2GameState? = nil
    var localParticipantID: UUID? = nil

    var needsToJoin: Bool {
        guard isJoiningPhase, let lpID = localParticipantID else { return false }
        return !seats.contains(lpID)
    }

    private init() {} // values are already initialized here ^

    // The View Controller will listen to these to know when to send the message
    var onTurnCompleted: ((Data, GameType) -> Void)?
    var onJoinCompleted: ((Data, GameType) -> Void)?
    
    enum TurnPhase {
        case animationPhase // Animating the opponents turn before your own
        case mainPhase      // Draw or discard!
        case idlePhase      // Opponent's turn
        case gameEndPhase   // Only unlocked upon a player winning
    }
    
    func isCardPlayable(_ card: Card) -> Bool {
        guard let topCard = discardPile.last else {
            return false
        }
        
        if card.rank == .eight {
            return true
        }
        
        if let requiredSuit = activeSuitOverride {
            return card.suit == requiredSuit
        }
        
        return card.suit == topCard.suit || card.rank == topCard.rank
    }
    
    func checkHandPlayability(){
        userCanDiscard = playerHand.contains { isCardPlayable($0) }
    }
    
    func drawFromDeck() {
        guard phase == .mainPhase, !deck.isEmpty, !userCanDiscard else { return }
        let card = deck.popLast()! //does the same thing as in the guard statement but we have to unwrap it anway
        playerHand.append(card)
        checkHandPlayability()
        cardsDrawnThisTurn += 1
        
        if cardsDrawnThisTurn == 3 && !userCanDiscard { //if youve drawn your 3rd card and still cannot play it, the user has to pass
            phase = .idlePhase
            sendGameStateSwitch()
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
        userDidDiscard = true
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
            isGameOver = true
            WinTracker.shared.incrementWins(for: "Crazy 8s")
        } else {
            phase = .idlePhase
        }
        
        sendGameStateSwitch()
    }
    
    func opponentDrawFromDeck() {
        guard phase == .animationPhase || isAnimatingOpponentTurn, !deck.isEmpty else { return }

        let card = deck.popLast()!
        opponentHand.append(card)
        opponentCardAnimatingFromDeck = card
    }

    func opponentDiscardCard(card: Card) { //pseudo discard
        guard phase == .animationPhase || isAnimatingOpponentTurn else { return }

        opponentHand.removeLast()
        discardPile.append(card)
        SoundManager.instance.playCardSlap()

        opponentHasWon = opponentHand.isEmpty
        if opponentHasWon {
            SoundManager.instance.playGameEnd(didWin: false)
            isAnimatingOpponentTurn = false
            phase = .gameEndPhase
            isGameOver = true
        } else if isAnimatingOpponentTurn {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.isAnimatingOpponentTurn = false
            }
        } else {
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
    
    func loadState(from data: Data, isPlayersTurn: Bool, localParticipantID: UUID = UUID(), isSinglePlayer: Bool = true, conversationID: String, isExplicitChange: Bool = false) {
        if isSinglePlayer == false, let v2State = try? JSONDecoder().decode(Crazy8sV2GameState.self, from: data) {
            loadV2State(state: v2State, localParticipantID: localParticipantID, conversationID: conversationID, isExplicitChange: isExplicitChange)
        } else if let legacyState = try? JSONDecoder().decode(Crazy8sLegacyGameState.self, from: data) {
            loadLegacyState(state: legacyState, isPlayersTurn: isPlayersTurn, conversationID: conversationID, isExplicitChange: isExplicitChange)
        } else {
            print("Error: Failed to decode Crazy8sGameState from data.")
        }
    }

    private func loadLegacyState(state: Crazy8sLegacyGameState, isPlayersTurn: Bool, conversationID: String, isExplicitChange: Bool) {
        let isInitialLoad = (self.sessionID == nil)
        let isSameSession = (self.sessionID == state.sessionID)
        let isNewTurn = state.turnNumber > self.turnNumber

        guard isInitialLoad || (isSameSession && isNewTurn) || isExplicitChange else { return }

        if isExplicitChange { resetToInit() }

        self.isSinglePlayer = true
        self.sessionID = state.sessionID
        self.turnNumber = state.turnNumber
        self.deck = state.deck
        self.discardPile = state.discardPile
        self.cardsDrawnThisTurn = 0
        self.userDidDiscard = false
        self.opponentDidDiscard = state.didDiscard
        if !opponentDidDiscard { //the opponent did not discard (they drew 3 cards)
            self.activeSuitOverride = state.activeSuitOverride //nil or the value the user set a turn prior
        } else { //they did discard, and if theres an active suit override, it gets displayed. else its nil and goes away
            hiddenActiveSuitOverride = state.activeSuitOverride
        }
        
        if isPlayersTurn { //the user is beginning their turn...
            self.playerHand = state.receiverHand
            let hasVisualsToAnimate = prepareOpponentsTurnForAnimation(state: state)
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
                isGameOver = true
            } else {
                phase = .idlePhase
            }
        }
    }

    private func loadV2State(state: Crazy8sV2GameState, localParticipantID: UUID, conversationID: String, isExplicitChange: Bool) {
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
            let joinRecord = "crazy8s_joined_\(state.sessionID.uuidString)"
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
        self.cardsDrawnThisTurn = 0
        self.userDidDiscard = false
        self.opponentDidDiscard = state.lastPlayerDidDiscard
        if !opponentDidDiscard {
            self.activeSuitOverride = state.activeSuitOverride
        } else {
            hiddenActiveSuitOverride = state.activeSuitOverride
        }

        let isMyTurn = (state.currentSeatIndex == seatIndex)
        self.playerHand = state.hands[seatIndex]
        let playerBeforeUser = (seatIndex - 1 + state.seats.count) % state.seats.count

        if isMyTurn {
            self.isSpectating = false
            self.isAnimatingOpponentTurn = false
            self.animatingOpponentSeat = playerBeforeUser
            let hasVisualsToAnimate = prepareOpponentsTurnForAnimationV2(state: state, previousSeat: playerBeforeUser)
            if hasVisualsToAnimate {
                phase = .animationPhase
            } else { //it is the first turn
                phase = .mainPhase
                checkHandPlayability()
            }
        } else { //it is not the current users turn
            self.isSpectating = true
            playerHasWon = self.playerHand.isEmpty
            if playerHasWon {
                phase = .gameEndPhase
                SoundManager.instance.playGameEnd(didWin: true)
                isGameOver = true
            } else {
                let lastPlayerSeat = (state.currentSeatIndex - 1 + state.seats.count) % state.seats.count
                self.animatingOpponentSeat = lastPlayerSeat
                let hasVisualsToAnimate = prepareOpponentsTurnForAnimationV2(state: state, previousSeat: lastPlayerSeat)
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
        self.userCanDiscard = false
        self.userNeedsToChooseSuit = false
        self.activeSuitOverride = nil
        self.hiddenActiveSuitOverride = nil
        self.cardsDrawnThisTurn = 0
        self.cardsOpponentDrew = 0
        self.userDidDiscard = false
        self.opponentDidDiscard = false
        self.playerHasWon = false
        self.opponentHasWon = false
        self.isGameOver = false
        self.opponentCardPendingDiscard = nil
        self.opponentCardAnimatingToDiscard = nil
        self.opponentCardAnimatingFromDeck = nil
        self.hasPerformedInitialLoad = false
        self.turnNumber = 0
        self.seats = []
        self.mySeatIndex = 0
        self.allHands = []
        self.isSpectating = false
        self.isAnimatingOpponentTurn = false
        self.animatingOpponentSeat = 0
        self.isSinglePlayer = false //we can check chat member count, this is probably redundant
        self.isJoiningPhase = false
        self.isSettlingAfterJoin = false
        self.joinWasOverwritten = false
        self.pendingJoinState = nil
    }
    
    private func prepareOpponentsTurnForAnimation(state: Crazy8sLegacyGameState) -> Bool {
        guard turnNumber > 0 else {
            self.opponentHand = state.senderHand //first turn! simple init, no turn to show
            return false
        }
        
        var opponentsHandPreAnimation = state.senderHand
        self.cardsOpponentDrew = state.cardsOpponentDrew
        
        if opponentDidDiscard {
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

    private func prepareOpponentsTurnForAnimationV2(state: Crazy8sV2GameState, previousSeat: Int) -> Bool {
        guard state.cardsDrawnByLastPlayer > 0 || state.lastPlayerDidDiscard else {
            self.opponentHand = state.hands[previousSeat]
            return false
        }

        var opponentsHandPreAnimation = state.hands[previousSeat]
        self.cardsOpponentDrew = state.cardsDrawnByLastPlayer

        if opponentDidDiscard {
            let cardTheyDiscarded = discardPile.popLast()!
            self.opponentCardPendingDiscard = cardTheyDiscarded
            opponentsHandPreAnimation.append(cardTheyDiscarded)
        } else {
            self.opponentCardPendingDiscard = nil
        }

        for _ in 0..<cardsOpponentDrew {
            if !opponentsHandPreAnimation.isEmpty {
                let cardToReturn = opponentsHandPreAnimation.removeLast()
                deck.append(cardToReturn)
            }
        }

        opponentHand = opponentsHandPreAnimation
        return true
    }

    func createNewGameState(seats: [UUID]) -> Data? {
        let newSessionID = UUID()
        let playerCount = seats.count

        // Scale decks dynamically: 1 deck for 1-5 players, 2 for 6-10, 3 for 11-15, etc.
        let decksNeeded = max(1, (playerCount - 1) / 5 + 1)
        var newDeck = (0..<decksNeeded)
            .flatMap { _ in Deck().cards }
            .shuffled()

        var newHands: [[Card]] = Array(repeating: [], count: playerCount)
        let handSize = playerCount == 2 ? 7 : 5
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
        
        if seats.count == 2 { //1v1 game mode , create legacy game state for now
            let legacyState = Crazy8sLegacyGameState(
                sessionID: newSessionID,
                deck: newDeck,
                discardPile: newDiscardPile,
                senderHand: newHands[0],
                receiverHand: newHands[1],
                cardsOpponentDrew: 0,
                didDiscard: false,
                activeSuitOverride: nil,
                turnNumber: 0,
            )
            self.isSinglePlayer = true
            return try? JSONEncoder().encode(legacyState)
            
        } else { //we have a groupchat
            let initialState = Crazy8sV2GameState(
                sessionID: newSessionID,
                deck: newDeck,
                discardPile: newDiscardPile,
                seats: seatList,
                hands: newHands,
                currentSeatIndex: 1 % playerCount,
                turnNumber: 0,
                cardsDrawnByLastPlayer: 0,
                lastPlayerDidDiscard: false,
                activeSuitOverride: nil
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
        UserDefaults.standard.set(joinData, forKey: "crazy8s_joined_\(state.sessionID.uuidString)")
        if shouldBroadcast {
            onJoinCompleted?(joinData, .crazy8s)
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
    
    func getJoinData(state: Crazy8sV2GameState, localParticipantID: UUID) -> Data? {
        guard !state.seats.contains(localParticipantID),
              let openIndex = state.seats.firstIndex(of: Self.unclaimedSeat) else { return nil }

        var updatedSeats = state.seats
        updatedSeats[openIndex] = localParticipantID

        let isLobbyNowFull = !updatedSeats.contains(Self.unclaimedSeat)
        let nextSeatIndex = isLobbyNowFull ? updatedSeats.firstIndex(of: localParticipantID)! : state.currentSeatIndex

        let updatedState = Crazy8sV2GameState(
            sessionID: state.sessionID,
            deck: state.deck,
            discardPile: state.discardPile,
            seats: updatedSeats,
            hands: state.hands,
            currentSeatIndex: nextSeatIndex,
            turnNumber: state.turnNumber + 1,
            cardsDrawnByLastPlayer: 0,
            lastPlayerDidDiscard: false,
            activeSuitOverride: state.activeSuitOverride)

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
        let currentGameState = Crazy8sLegacyGameState(
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

        self.turnNumber += 1
        self.onTurnCompleted?(stateData, .crazy8s)
    }

    private func sendV2GameState() {
        allHands[mySeatIndex] = playerHand
        let previousSeat = (mySeatIndex - 1 + seats.count) % seats.count //why do we care about previousSeat here?
        if turnNumber > 0 {
            allHands[previousSeat] = opponentHand //why do we set previous seat on our turn?
        }

        let nextSeat = (mySeatIndex + 1) % seats.count

        let currentGameState = Crazy8sV2GameState(
            sessionID: self.sessionID!,
            deck: self.deck,
            discardPile: self.discardPile,
            seats: self.seats,
            hands: self.allHands,
            currentSeatIndex: nextSeat,
            turnNumber: self.turnNumber + 1,
            cardsDrawnByLastPlayer: self.cardsDrawnThisTurn,
            lastPlayerDidDiscard: self.userDidDiscard,
            activeSuitOverride: self.activeSuitOverride
        )

        guard let stateData = try? JSONEncoder().encode(currentGameState) else {
            print("Error: Failed to encode Crazy8sGameStateV2 into Data.")
            return
        }

        self.turnNumber += 1
        self.onTurnCompleted?(stateData, .crazy8s)
    }
    
}
