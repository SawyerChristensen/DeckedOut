//
//  Crazy8sManager.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 2/23/26.
//

import Foundation

// Regional rule variant. The mechanics are identical across variants; only the
// ranks that trigger them differ, so the same engine serves both. The variant is
// fixed when a game is created and travels in the payload so every participant —
// regardless of their own region — interprets the shared card state the same way.
enum Crazy8sVariant: String, Codable {
    case crazy8s // International default: 8 wild, 2 draws, Queen skips, Ace reverses
    case mauMau  // German variant: Jack wild, 7 draws, 8 skips, 9 reverses

    var wildRank: Rank    { self == .mauMau ? .jack  : .eight } // choose the next suit
    var drawTwoRank: Rank { self == .mauMau ? .seven : .two   } // next player draws two
    var skipRank: Rank    { self == .mauMau ? .eight : .queen } // skip the next player
    var reverseRank: Rank { self == .mauMau ? .nine  : .ace   } // reverse direction (groupchat)

    /// The variant a newly created game should use, based on the creator's region.
    /// German-speaking regions default to Mau Mau; everyone else gets Crazy 8s.
    static func forCurrentRegion() -> Crazy8sVariant {
        let germanRegions: Set<String> = ["DE", "AT", "CH", "LI"]
        if let region = Locale.current.region?.identifier, germanRegions.contains(region) {
            return .mauMau
        }
        return .crazy8s
    }
}

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
    let senderCardBack: String? //the card-back the sender has equipped; optional for backward compat
    let penaltyCardsDealt: Int? //cards forced on receiver due to a wild card (e.g. a 2); optional for backward compat
    let variant: Crazy8sVariant? //regional rule variant; optional for backward compat (absent = .crazy8s)
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
    let seatCardBacks: [String]? //parallel to seats; optional for backward compat
    let penaltyCardsDealt: Int? //cards forced on next player due to a wild card (e.g. a 2); optional for backward compat
    let lastPlayerSeatIndex: Int? //who actually played last turn; differs from (currentSeatIndex - 1) when a queen skipped a seat. Optional for backward compat
    let directionIsReversed: Bool? //flipped each time an ace is played; controls whether seat advancement is +1 or -1. Optional for backward compat
    let variant: Crazy8sVariant? //regional rule variant; optional for backward compat (absent = .crazy8s)
}

// MARK: The Game Engine
class Crazy8sManager: ObservableObject, GameEngine, GroupChatCapable {
    static let shared = Crazy8sManager()
    static let unclaimedSeat = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    @Published var extensionWidth: CGFloat = 375
    var variant: Crazy8sVariant = .crazy8s //regional rule variant; set at creation and decoded from the payload on load
    @Published var sessionID: UUID? = nil
    @Published var deck: [Card] = []
    @Published var discardPile: [Card] = []
    @Published var playerHand: [Card] = []
    // Snapshot of playerHand taken on the first sort of a cycle, restored when the user returns to the unsorted state.
    private var originalPlayerHandOrder: [Card]? = nil
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
    @Published var opponentQueensPendingDiscard: [Card] = [] // V1 1v1: queens the opponent played before the final discard, in chronological animation order
    @Published var opponentCardAnimatingToDiscard: Card? = nil       // The trigger the view actually watches
    @Published var opponentCardAnimatingFromDeck: Card? = nil        // The trigger for draw animations
    @Published var penaltyCardsForcedOnOpponent: Int = 0 // count of cards we forced on the opponent this turn (e.g. via a 2)
    @Published var pendingPlayerPenaltyDraws: Int = 0 // count of cards the local player needs to receive as a penalty animation
    @Published var deckShouldShowPlayerBack: Bool = false // flip the deck to the user's card back ahead of penalty draws so the animated card and the deck share a back
    private var skipNextSeat: Bool = false // set when the user plays a queen in V2; advances currentSeatIndex by 2 on send
    private var previousPlayerSeatIndex: Int = 0 // the actual seat that played the previous turn (handles queen-skip)
    private var isDirectionReversed: Bool = false // toggled when an ace is played in V2; flips seat-advancement direction
    var hasPerformedInitialLoad: Bool = false //stays local. this is just for the 0.5 delay in game view when you open a message

    // Card-back equipped by each player (sent in the message payload)
    @Published var opponentCardBack: String = "cardBackRed" //v1: the single opponent's equipped back
    @Published var seatCardBacks: [String] = [] //v2: parallel to `seats`; updated each turn

    // Multiplayer (V2) properties
    var seats: [UUID] = []
    var mySeatIndex: Int = 0
    @Published var allHands: [[Card]] = []
    var is1v1: Bool = false
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

    /// Returns the card-back image name for a specific seat. Falls back to `cardBackRed`.
    func cardBack(forSeat seatIndex: Int) -> String {
        if is1v1 { return opponentCardBack }
        return seatCardBacks.indices.contains(seatIndex) ? seatCardBacks[seatIndex] : "cardBackRed"
    }

    /// Card-back to display on the deck/discard stacks when it isn't the user's turn.
    /// During animation, matches the seat currently drawing from the deck so the animated card and the deck share a back.
    /// Otherwise reflects the upcoming player's back so the deck updates as soon as the previous turn lands.
    var opponentDeckCardBack: String {
        if is1v1 { return opponentCardBack }
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
        case mainPhase      // Draw or discard!
        case idlePhase      // Opponent's turn
        case gameEndPhase   // Only unlocked upon a player winning
    }
    
    func isCardPlayable(_ card: Card) -> Bool {
        guard let topCard = discardPile.last else {
            return false
        }
        
        if card.rank == variant.wildRank {
            // Mau Mau: a Jack (wild) may not be played on another Jack.
            if variant == .mauMau && topCard.rank == variant.wildRank { return false }
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
    
    func sortPlayerHand(sortState: Int) {
        // sortState: 0 = original unsorted order, 1 = sorted by suit then rank, 2 = sorted by rank
        if sortState == 0 {
            if let snapshot = originalPlayerHandOrder {
                // Restore the snapshot, accounting for cards drawn or discarded since it was taken
                let currentIDs = Set(playerHand.map(\.id))
                var restored = snapshot.filter { currentIDs.contains($0.id) }
                let snapshotIDs = Set(snapshot.map(\.id))
                restored.append(contentsOf: playerHand.filter { !snapshotIDs.contains($0.id) })
                playerHand = restored
                originalPlayerHandOrder = nil
            }
            HapticManager.instance.playCardReorder()
            return
        }

        // Capture the pre-sort order the first time we sort in a cycle
        if originalPlayerHandOrder == nil {
            originalPlayerHandOrder = playerHand
        }

        let sortedHand = playerHand.sorted { card1, card2 in
            if sortState == 1 {
                if card1.suit.rawValue != card2.suit.rawValue {
                    return card1.suit.rawValue < card2.suit.rawValue
                }
                return card1.rank.rawValue < card2.rank.rawValue
            }
            // sortState == 2: sort by rank, suit as tiebreaker
            if card1.rank.rawValue != card2.rank.rawValue {
                return card1.rank.rawValue < card2.rank.rawValue
            }
            return card1.suit.rawValue < card2.suit.rawValue
        }

        playerHand = sortedHand
        HapticManager.instance.playCardReorder()
    }
    
    func discardCard(card: Card) { // Removed chosenSuit from here, we'll handle it separately
        //isCardPlayable centralizes legality (suit/rank match, wild, and the Mau Mau Jack-on-Jack rule)
        guard phase == .mainPhase, isCardPlayable(card), let index = playerHand.firstIndex(of: card) else {
            HapticManager.instance.playErrorFeedback()
            return
        }

        playerHand.remove(at: index)
        discardPile.append(card)
        userDidDiscard = true
        SoundManager.instance.playCardSlap()
        HapticManager.instance.playCardSlap()

        if card.rank == variant.wildRank {
            GameCenterManager.shared.report(achievement: .discardEight)
            userNeedsToChooseSuit = true //signals GameView to prompt the user for a new suit
        } else if card.rank == variant.drawTwoRank {
            GameCenterManager.shared.report(achievement: .discardTwo)
            //block further player interaction while the penalty animation plays
            phase = .animationPhase
            activeSuitOverride = nil
            Task { @MainActor in
                await dealPenaltyCards(count: 2)
                completeTurn()
            }
        } else if card.rank == variant.skipRank {
            GameCenterManager.shared.report(achievement: .discardQueen)
            activeSuitOverride = nil
            if is1v1 && !playerHand.isEmpty {
                //skip the opponent: keep playing locally without sending. fresh draw allowance for the bonus turn.
                //this bonus play won't route through sendGameStateSwitch, so count it as a personal turn here.
                _ = recordLocalTurn()
                cardsDrawnThisTurn = 0
                checkHandPlayability()
            } else {
                if !is1v1 { skipNextSeat = true }
                completeTurn()
            }
        } else if card.rank == variant.reverseRank && !is1v1 {
            //reverse direction in V2 groupchat; in V1 legacy the reverse rank plays as a normal card (handled by the else below)
            GameCenterManager.shared.report(achievement: .discardAce)
            isDirectionReversed.toggle()
            activeSuitOverride = nil
            completeTurn()
        } else {
            activeSuitOverride = nil
            completeTurn()
        }
    }

    @MainActor
    private func dealPenaltyCards(count: Int) async {
        //In V2 3+ player, swap the active opponent slot to the next seat so the penalty draws animate into their hand.
        let isMultiOpponent = !is1v1 && seats.count > 2
        let step = isDirectionReversed ? -1 : 1
        let nextSeat = seats.isEmpty ? 0 : ((mySeatIndex + step) % seats.count + seats.count) % seats.count

        if isMultiOpponent {
            animatingOpponentSeat = nextSeat
            opponentHand = allHands.indices.contains(nextSeat) ? allHands[nextSeat] : []
        }

        for _ in 0..<count {
            //If the deck would run out mid-penalty, reshuffle the discard pile back into the deck (preserving the top 2 cards).
            if deck.isEmpty, discardPile.count > 2 {
                let topDiscard = discardPile.popLast()!
                let secondDiscard = discardPile.popLast()!
                deck = discardPile.shuffled()
                discardPile = [secondDiscard, topDiscard]
            }
            guard !deck.isEmpty else { break }
            let drawn = deck.popLast()!
            opponentHand.append(drawn)
            if isMultiOpponent, allHands.indices.contains(nextSeat) {
                allHands[nextSeat].append(drawn)
            }
            opponentCardAnimatingFromDeck = drawn
            penaltyCardsForcedOnOpponent += 1
            try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s, matches opponent draw cadence
        }

        if isMultiOpponent {
            //restore opponentHand to the previous opponent's hand so sendV2GameState's previousSeat assignment is a no-op
            opponentHand = allHands.indices.contains(previousPlayerSeatIndex) ? allHands[previousPlayerSeatIndex] : []
        }
    }

    func userDrawPenaltyCard() {
        guard pendingPlayerPenaltyDraws > 0 else { return }
        if deck.isEmpty { return } //deck should already contain unwound penalty cards from prepareOpponentsTurnForAnimation
        let card = deck.popLast()!
        playerHand.append(card)
        pendingPlayerPenaltyDraws -= 1
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
            GameCenterManager.shared.reportWin(firstWin: .firstWinCrazy8s)
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
        HapticManager.instance.playCardSlap()

        opponentHasWon = opponentHand.isEmpty
        if opponentHasWon {
            SoundManager.instance.playGameEnd(didWin: false)
            isAnimatingOpponentTurn = false
            phase = .gameEndPhase
            isGameOver = true
        } else if pendingPlayerPenaltyDraws > 0 {
            //animateOpponentsTurn will run penalty draws next and complete the phase transition afterwards
        } else if !opponentQueensPendingDiscard.isEmpty {
            //V1 1v1: more queens (and the final card) still need to animate; stay in animationPhase
            //so subsequent opponentDiscardCard calls pass the guard.
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
    
    func loadState(from data: Data, isPlayersTurn: Bool, localParticipantID: UUID = UUID(), is1v1: Bool = true, conversationID: String, isExplicitChange: Bool = false) {
        if is1v1 == false, let v2State = try? JSONDecoder().decode(Crazy8sV2GameState.self, from: data) {
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

        self.is1v1 = true
        self.variant = state.variant ?? .crazy8s
        self.sessionID = state.sessionID
        self.turnNumber = state.turnNumber
        self.deck = state.deck
        self.discardPile = state.discardPile
        if isPlayersTurn, let sentBack = state.senderCardBack {
            self.opponentCardBack = sentBack
        }
        self.cardsDrawnThisTurn = 0
        self.userDidDiscard = false
        self.penaltyCardsForcedOnOpponent = 0
        self.pendingPlayerPenaltyDraws = 0
        self.deckShouldShowPlayerBack = false
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
        self.is1v1 = false
        self.variant = state.variant ?? .crazy8s
        self.sessionID = state.sessionID
        self.turnNumber = state.turnNumber
        self.seats = state.seats
        self.deck = state.deck
        self.discardPile = state.discardPile
        self.allHands = state.hands
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
        self.cardsDrawnThisTurn = 0
        self.userDidDiscard = false
        self.penaltyCardsForcedOnOpponent = 0
        self.pendingPlayerPenaltyDraws = 0
        self.deckShouldShowPlayerBack = false
        self.opponentDidDiscard = state.lastPlayerDidDiscard
        if !opponentDidDiscard {
            self.activeSuitOverride = state.activeSuitOverride
        } else {
            hiddenActiveSuitOverride = state.activeSuitOverride
        }
        self.isDirectionReversed = state.directionIsReversed ?? false

        let isMyTurn = (state.currentSeatIndex == seatIndex)
        self.playerHand = state.hands[seatIndex]
        //use the explicit lastPlayerSeatIndex when present (set when a queen skipped a seat); fall back to (currentSeatIndex - 1) for legacy compat.
        let actualPreviousPlayer = state.lastPlayerSeatIndex ?? ((state.currentSeatIndex - 1 + state.seats.count) % state.seats.count)
        self.previousPlayerSeatIndex = actualPreviousPlayer

        if isMyTurn {
            self.isSpectating = false
            self.isAnimatingOpponentTurn = false
            self.animatingOpponentSeat = actualPreviousPlayer
            let hasVisualsToAnimate = prepareOpponentsTurnForAnimationV2(state: state, previousSeat: actualPreviousPlayer)
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
                self.animatingOpponentSeat = actualPreviousPlayer
                let hasVisualsToAnimate = prepareOpponentsTurnForAnimationV2(state: state, previousSeat: actualPreviousPlayer)
                phase = .idlePhase
                isAnimatingOpponentTurn = hasVisualsToAnimate
            }
        }
    }
    
    private func resetToInit() {
        self.variant = .crazy8s //load() reassigns this from the incoming state immediately after reset
        self.sessionID = nil
        self.playerHand = []
        self.originalPlayerHandOrder = nil // otherwise a previous game's sort snapshot blocks capturing the new hand's order
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
        self.opponentQueensPendingDiscard = []
        self.opponentCardAnimatingToDiscard = nil
        self.opponentCardAnimatingFromDeck = nil
        self.penaltyCardsForcedOnOpponent = 0
        self.pendingPlayerPenaltyDraws = 0
        self.deckShouldShowPlayerBack = false
        self.skipNextSeat = false
        self.previousPlayerSeatIndex = 0
        self.isDirectionReversed = false
        self.hasPerformedInitialLoad = false
        self.turnNumber = 0
        self.seats = []
        self.mySeatIndex = 0
        self.allHands = []
        self.isSpectating = false
        self.isAnimatingOpponentTurn = false
        self.animatingOpponentSeat = 0
        self.is1v1 = false //we can check chat member count, this is probably redundant
        self.isJoiningPhase = false
        self.isSettlingAfterJoin = false
        self.joinWasOverwritten = false
        self.pendingJoinState = nil
        self.opponentCardBack = "cardBackRed"
        self.seatCardBacks = []
    }

    private func prepareOpponentsTurnForAnimation(state: Crazy8sLegacyGameState) -> Bool {
        let penaltyCards = state.penaltyCardsDealt ?? 0
        guard turnNumber > 0 else {
            self.opponentHand = state.senderHand //first turn! simple init, no turn to show
            return false
        }

        var opponentsHandPreAnimation = state.senderHand
        self.cardsOpponentDrew = state.cardsOpponentDrew
        
        self.opponentQueensPendingDiscard = []
        if opponentDidDiscard {
            let cardTheyDiscarded = discardPile.popLast()! //we will animate it back later...
            self.opponentCardPendingDiscard = cardTheyDiscarded
            opponentsHandPreAnimation.append(cardTheyDiscarded)

            //In 1v1, a queen grants the opponent another turn. Pop any queens stacked beneath the
            //final discard so we animate the full sequence chronologically instead of skipping
            //straight to the last card. Queens are appended to the opponent's hand in pop order
            //(newest first) so the oldest queen ends up at the tail — opponentDiscardCard's
            //removeLast() then peels them off in animation order.
            //Skip on turn 1: the discard pile may have been initialized with a queen that nobody played.
            if turnNumber > 1, discardPile.count != 2 {
                var queens: [Card] = []
                while discardPile.last?.rank == variant.skipRank {
                    let queen = discardPile.popLast()!
                    queens.append(queen)
                    opponentsHandPreAnimation.append(queen)
                }
                self.opponentQueensPendingDiscard = queens.reversed() //store oldest-first for iteration
            }
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

        //unwind penalty cards from the local player's hand so they can animate from the deck during the animation phase
        if penaltyCards > 0 {
            for _ in 0..<penaltyCards {
                if !playerHand.isEmpty {
                    deck.append(playerHand.removeLast())
                }
            }
            pendingPlayerPenaltyDraws = penaltyCards
        }
        return true
    }

    private func prepareOpponentsTurnForAnimationV2(state: Crazy8sV2GameState, previousSeat: Int) -> Bool {
        let penaltyCards = state.penaltyCardsDealt ?? 0
        let hasOpponentVisuals = state.cardsDrawnByLastPlayer > 0 || state.lastPlayerDidDiscard
        let hasPenaltyVisualsForLocal = penaltyCards > 0 && state.currentSeatIndex == mySeatIndex

        guard hasOpponentVisuals || hasPenaltyVisualsForLocal else {
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

        //unwind penalty cards from the upcoming player's hand. Only animate them if the local player is the recipient;
        //spectators in 3+ player V2 will see the static hand grow without a dedicated penalty animation.
        if penaltyCards > 0, state.currentSeatIndex == mySeatIndex {
            for _ in 0..<penaltyCards {
                if !playerHand.isEmpty {
                    deck.append(playerHand.removeLast())
                }
            }
            if allHands.indices.contains(state.currentSeatIndex) {
                allHands[state.currentSeatIndex] = playerHand
            }
            pendingPlayerPenaltyDraws = penaltyCards
        }
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
        
        let myCardBack = CurrentTheme.shared.selectedName

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
                senderCardBack: myCardBack,
                penaltyCardsDealt: nil,
                variant: variant
            )
            self.is1v1 = true
            return try? JSONEncoder().encode(legacyState)

        } else { //we have a groupchat
            var initialBacks = Array(repeating: "cardBackRed", count: playerCount)
            initialBacks[0] = myCardBack
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
                activeSuitOverride: nil,
                seatCardBacks: initialBacks,
                penaltyCardsDealt: nil,
                lastPlayerSeatIndex: nil,
                directionIsReversed: nil,
                variant: variant
            )
            self.is1v1 = false
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
        loadState(from: joinData, isPlayersTurn: false, localParticipantID: lpID, is1v1: false, conversationID: "")
        
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

        var updatedBacks = state.seatCardBacks ?? Array(repeating: "cardBackRed", count: state.seats.count)
        if updatedBacks.count < updatedSeats.count {
            updatedBacks.append(contentsOf: Array(repeating: "cardBackRed", count: updatedSeats.count - updatedBacks.count))
        }
        updatedBacks[openIndex] = CurrentTheme.shared.selectedName

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
            activeSuitOverride: state.activeSuitOverride,
            seatCardBacks: updatedBacks,
            penaltyCardsDealt: nil,
            lastPlayerSeatIndex: nil,
            directionIsReversed: state.directionIsReversed,
            variant: state.variant)

        return try? JSONEncoder().encode(updatedState)
    }

    /// Increments and returns the number of turns the local player has personally taken this session.
    /// Stored in UserDefaults keyed by sessionID so it survives the manager being rebuilt each turn.
    private func recordLocalTurn() -> Int {
        guard let sessionID else { return 0 }
        let key = "crazy8s_myturns_\(sessionID.uuidString)"
        let next = UserDefaults.standard.integer(forKey: key) + 1
        UserDefaults.standard.set(next, forKey: key)
        return next
    }

    func sendGameStateSwitch() {
        if deck.count == 1 { reshuffleDiscardIntoDeck() }

        // Count this as one of the local player's turns. Persisted per-session because the manager
        // is rebuilt from the message payload between turns, so an in-memory counter wouldn't survive.
        // Winning on exactly the 8th personal turn earns the Crazy 8s master achievement.
        let myTurnCount = recordLocalTurn()
        if playerHasWon && myTurnCount == 8 {
            GameCenterManager.shared.report(achievement: .crazy8sMaster)
        }

        if is1v1 {
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
            turnNumber: self.turnNumber + 1,
            senderCardBack: CurrentTheme.shared.selectedName,
            penaltyCardsDealt: penaltyCardsForcedOnOpponent > 0 ? penaltyCardsForcedOnOpponent : nil,
            variant: variant
        )

        guard let stateData = try? JSONEncoder().encode(currentGameState) else {
            print("Error: Failed to encode Crazy8sGameState into Data.")
            return
        }

        self.turnNumber += 1
        //Defer the iMessage send to the next runloop so SwiftUI commits the discard state change
        //(hand shrink + new discard top card) before the conversation.send pipeline runs.
        Task { @MainActor [weak self] in
            self?.onTurnCompleted?(stateData, .crazy8s)
        }
    }

    private func sendV2GameState() {
        allHands[mySeatIndex] = playerHand
        if turnNumber > 0 {
            //sync our view of the previous player's hand (handles queen-skip via previousPlayerSeatIndex)
            allHands[previousPlayerSeatIndex] = opponentHand
        }

        //skipNextSeat advances by 2 instead of 1 when the user played a queen; direction follows the ace-toggled flag
        let step = isDirectionReversed ? -1 : 1
        let advancement = (skipNextSeat ? 2 : 1) * step
        let nextSeat = ((mySeatIndex + advancement) % seats.count + seats.count) % seats.count

        var outgoingBacks = seatCardBacks
        if outgoingBacks.count < seats.count {
            outgoingBacks.append(contentsOf: Array(repeating: "cardBackRed", count: seats.count - outgoingBacks.count))
        }
        if outgoingBacks.indices.contains(mySeatIndex) {
            outgoingBacks[mySeatIndex] = CurrentTheme.shared.selectedName
        }

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
            activeSuitOverride: self.activeSuitOverride,
            seatCardBacks: outgoingBacks,
            penaltyCardsDealt: penaltyCardsForcedOnOpponent > 0 ? penaltyCardsForcedOnOpponent : nil,
            lastPlayerSeatIndex: mySeatIndex,
            directionIsReversed: isDirectionReversed,
            variant: variant
        )

        guard let stateData = try? JSONEncoder().encode(currentGameState) else {
            print("Error: Failed to encode Crazy8sGameStateV2 into Data.")
            return
        }

        self.turnNumber += 1
        // Mark our seat as the one who just played so the deck immediately reflects the next player's back.
        self.seatCardBacks = outgoingBacks
        self.animatingOpponentSeat = mySeatIndex
        self.skipNextSeat = false
        //Defer the iMessage send to the next runloop so SwiftUI commits the discard state change first.
        Task { @MainActor [weak self] in
            self?.onTurnCompleted?(stateData, .crazy8s)
        }
    }

}
