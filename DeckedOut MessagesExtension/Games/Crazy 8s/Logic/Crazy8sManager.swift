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
    case crazy8s   // International default: 8 wild, 2 draws, Queen skips, Ace reverses
    case mauMau    // German variant: Jack wild, 7 draws, 8 skips, 9 reverses
    case irishSwitch // UK/Ireland "Switch": Ace wild, 2 draws two, switch jacks draw five (red jacks cancel), 8 skips, King reverses
    case pesten    // Dutch "Pesten": Jack wild, 2 draws two, 7 plays again (sticky seven), 8 skips, Ace reverses

    var wildRank: Rank { // choose the next suit
        switch self {
        case .crazy8s:   return .eight
        case .mauMau:    return .jack
        case .irishSwitch: return .ace
        case .pesten:    return .jack
        }
    }
    var drawTwoRank: Rank { // next player draws two
        switch self {
        case .crazy8s:   return .two
        case .mauMau:    return .seven
        case .irishSwitch: return .two
        case .pesten:    return .two
        }
    }
    var skipRank: Rank { // skip the next player
        switch self {
        case .crazy8s:   return .queen
        case .mauMau:    return .eight
        case .irishSwitch: return .eight
        case .pesten:    return .eight
        }
    }
    var reverseRank: Rank { // reverse direction (groupchat)
        switch self {
        case .crazy8s:   return .ace
        case .mauMau:    return .nine
        case .irishSwitch: return .king
        case .pesten:    return .ace
        }
    }
    /// A rank that grants the player an immediate bonus turn instead of passing (Pesten's "sticky
    /// seven"). nil for variants without the mechanic. Comparing a non-optional `Rank` against this
    /// yields false when nil, so the play-again branch stays dormant for every other variant.
    var playAgainRank: Rank? {
        switch self {
        case .pesten: return .seven
        default:      return nil
        }
    }
    /// The variant a newly created game should use, based on the creator's region.
    /// Regions where the game is traditionally played under a local ruleset default to
    /// that variant; everyone else gets Crazy 8s.
    static func forCurrentRegion() -> Crazy8sVariant {
        guard let region = Locale.current.region?.identifier else { return .crazy8s }
        // German-speaking regions (DE, AT, CH, LI) plus Brazil (BR), & Portugal (PT)
        let mauMauRegions: Set<String> = ["DE", "AT", "CH", "LI", "BR", "PT"]
        // UK and Ireland, where it's played as "Switch".
        let switchRegions: Set<String> = ["GB", "IE"]
        // The Netherlands and Belgium (Flanders), where it's played as "Pesten".
        let pestenRegions: Set<String> = ["NL", "BE"]
        if mauMauRegions.contains(region) { return .mauMau }
        if switchRegions.contains(region) { return .irishSwitch }
        if pestenRegions.contains(region) { return .pesten }
        return .crazy8s
    }

    /// The player-facing name of this variant, translated into the reader's language.
    /// The name follows the *variant* (which travels in the payload), so every participant
    /// sees the same game name regardless of their own region — a US reader opening a
    /// German-created game still sees "Mau-Mau".
    var displayName: String {
        switch self {
        case .crazy8s:     return String(localized: "Crazy 8s", comment: "Game title for Crazy 8s, displayed in the main menu")
        case .mauMau:      return String(localized: "Mau-Mau", comment: "Game title for the German Mau-Mau variant of Crazy 8s")
        case .irishSwitch: return String(localized: "Switch", comment: "Game title for the UK/Ireland Switch variant of Crazy 8s")
        case .pesten:      return String(localized: "Pesten", comment: "Game title for the Dutch Pesten variant of Crazy 8s")
        }
    }

    /// The name spelled out one glyph per card back across the transcript hand. Crazy 8s keeps
    /// its hand-tuned per-language spelling; the proper-name variants spell out `displayName`
    /// (dropping separators like the hyphen in "Mau-Mau").
    var titleLetters: [String] {
        switch self {
        case .mauMau, .irishSwitch, .pesten:
            return displayName.uppercased().compactMap { $0.isLetter || $0.isNumber ? String($0) : nil }
        case .crazy8s:
            let currentLanguage = Locale.preferredLanguages.first ?? "en"
            if currentLanguage.hasPrefix("zh-Hans") {
                return ["疯", "狂", "8"]
            } else if currentLanguage.hasPrefix("zh-Hant") {
                return ["瘋", "狂", "8"]
            } else if currentLanguage.hasPrefix("da") {
                return ["O", "L", "S", "E", "N"]
            } else if currentLanguage.hasPrefix("fr") {
                return ["8", "A", "M", "E", "R", "I", "C", "A", "I", "N"]
            } else if currentLanguage.hasPrefix("pt") {
                return ["O", "I", "T", "O", "M", "A", "L", "U", "C", "O"]
            } else if currentLanguage.hasPrefix("hi") {
                return ["क्रे", "ज़ी", "8", "S"]
            } else if currentLanguage.hasPrefix("it") {
                return ["O", "T", "T", "O"]
            } else if currentLanguage.hasPrefix("ja") {
                return ["ク", "レ", "イ", "ジ", "ー", "エ", "イ", "ト"]
            } else if currentLanguage.hasPrefix("ko") {
                return ["크", "레", "이", "지", "8"]
            } else if currentLanguage.hasPrefix("nb") {
                return ["V", "R", "I", "A", "T", "T", "E", "R"]
            //} else if currentLanguage.hasPrefix("pt") {
                //return ["O", "I", "T", "O", "M", "A", "L", "U", "C", "O"]
            } else if currentLanguage.hasPrefix("ru") {
                return ["В", "О", "С", "Ь", "М", "Ё", "Р", "К", "И"]
            } else if currentLanguage.hasPrefix("es") {
                return ["O", "C", "H", "O", "S", "L", "O", "C", "O", "S"]
            } else if currentLanguage.hasPrefix("sv") {
                return ["V", "A", "N", "D", "A", "T", "T", "A"]
            } else if currentLanguage.hasPrefix("tr") {
                return ["C", "I", "L", "G", "I", "N", "8", "L", "I"]
            } else { // Default (English)
                return ["C", "R", "A", "Z", "Y", "8", "S"]
            }
        }
    }

    /// The word "pages" the invite transcript hand flips between, one glyph per card, e.g.
    /// Gin's `LETS / PLAY / GIN!`. Distinct from `titleLetters` (a single static spelling):
    /// the invite cycles a flip animation across these pages.
    ///
    /// **Every page in a returned set must be the same character length** so the fanned hand
    /// stays even (like `CRAZY`/`EIGHT` or `OCHOS`/`LOCOS`, both 5). Only add a
    /// `lang.hasPrefix(...)` branch for a language whose spelling splits into equal-length
    /// pages; anything ragged should fall through to the English default. The proper-name
    /// variants aren't localized (Mau-Mau/Switch are the same in every language).
    var titleWords: [String] {
        let lang = Locale.preferredLanguages.first ?? "en"
        switch self {
        case .mauMau:
            if lang.hasPrefix("de") { return ["ZEIT", "FURS", "MAU~", "MAU!"] }  // 4, 4, 4, 4
            if lang.hasPrefix("en") { return ["LETS", "PLAY", "MAU~", "MAU!"] }  // 4, 4, 4, 4
            return ["MAU", "MAU"]                                                // 3, 3
        case .irishSwitch:
            return ["~LETS~", "~PLAY~", "SWITCH"]                                // 6, 6, 6
        case .pesten:
            return ["~LETS~", "~PLAY~", "PESTEN"]                                // 6, 6, 6
        case .crazy8s:
            if lang.hasPrefix("zh-Hant") { return ["讓我們", "一起玩", "瘋狂8"] }   // 3, 3, 3
            if lang.hasPrefix("zh-Hans") { return ["让我们", "一起玩", "疯狂8"] }   // 3, 3, 3
            if lang.hasPrefix("es")      { return ["OCHOS", "LOCOS"] }           // 5, 5
            return ["CRAZY", "EIGHT"]                                            // Default (English), 5, 5
        }
    }
}

// A Switch counter that resolved during the sender's turn: they played `switchJack`
// (J♠/J♣) and the receiver's `redJack` (J♥/J♦) cancelled the pick-up-5. Recorded so the receiver
// can replay the exchange. Metadata (not discard order) drives the replay, since a red jack is also
// a legal normal play on a switch jack and a reshuffle can reorder the pile.
struct SwitchCounter: Codable {
    let switchJack: Card // the card the sender played
    let redJack: Card   // the card the receiver auto-played to cancel it
}

// One atomic, animatable event within a single player's turn, recorded in chronological order by
// the acting player and replayed verbatim by the next player. This is the animation "script": it
// replaces reverse-engineering the turn from the final snapshot (drawn-card counts, stacked-queen
// probing, switch-counter metadata). Semantics are relative to the acting (sending) player, so on
// the receiver's side `draw`/`play` belong to the opponent and `forceDraw`/`counterPlay` involve
// the local player. `Card` and `Suit` both encode as a single Int, so the log stays compact.
enum Crazy8sTurnAction: Codable {
    case draw(Card)                        // the acting player drew this card from the deck
    case play(Card, fromIndex: Int)        // the acting player played this card from this hand index onto the discard
    case chooseSuit(Suit)                  // the acting player selected the active suit (after a wild)
    case forceDraw(Card)                   // the acting player forced this card from the deck onto the NEXT player
    case counterPlay(Card, fromIndex: Int) // the NEXT player auto-played this card (from this index of their hand) during the acting turn (e.g. Switch red-jack cancel)
    case seatPlay(Card, fromIndex: Int, seat: Int) // a non-acting seat auto-played a draw-two during a group-chat stack; replayed from that seat's arc position, skipping that seat's turn
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
    let switchCounters: [SwitchCounter]? //Switch: switch-jack/red-jack cancels this turn, chronological; optional for backward compat
    let turnActions: [Crazy8sTurnAction]? //chronological animation script for this turn; optional for backward compat (absent = snap, no animation)
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
    let turnActions: [Crazy8sTurnAction]? //chronological animation script for this turn; optional for backward compat (absent = snap, no animation)
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
    @Published var cardsDrawnThisTurn: Int = 0 //cards the local player has drawn this turn; sent as cardsOpponentDrew for legacy-client compat
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
    @Published var opponentCardAnimatingToDiscard: Card? = nil       // The trigger the view actually watches
    @Published var opponentCardAnimatingFromDeck: Card? = nil        // The trigger for draw animations
    // Set the instant an opponent's card lands on the discard pile: holds that opponent's equipped
    // card-back name. The discard pile reads it to cross-fade the just-landed card's front from the
    // opponent's theme into the local player's equipped theme (opponent turn ending → player turn
    // beginning), then clears it. nil at every other time — this is the ONLY moment a front fades.
    @Published var discardCrossfadeFromBack: String? = nil
    @Published var playerCardAnimatingToDiscard: Card? = nil         // Switch: trigger to fly one of the local player's own cards to the discard (used to replay their red-jack counter)
    // The chronological animation script for the turn being replayed (decoded from the incoming
    // payload). animateOpponentsTurn walks it in order; each entry maps to one animation.
    @Published var actionsToAnimate: [Crazy8sTurnAction] = []
    // Actions accumulated during the local player's turn (across bonus plays), sent in the payload.
    private var turnActions: [Crazy8sTurnAction] = []
    private var switchCountersThisTurn: [SwitchCounter] = []   // Switch: counters accumulated during the local player's turn; sent in the payload (legacy compat)
    @Published var penaltyCardsForcedOnOpponent: Int = 0 // count of cards we forced on the opponent this turn (e.g. via a 2)
    @Published var pendingPlayerPenaltyDraws: Int = 0 // count of cards the local player needs to receive as a penalty animation
    @Published var deckShouldShowPlayerBack: Bool = false // flip the deck to the user's card back ahead of penalty draws so the animated card and the deck share a back
    private var skipNextSeat: Bool = false // set when the user plays a queen in V2; advances currentSeatIndex by 2 on send
    private var overrideNextSeat: Int? = nil // set during a group-chat draw-two stack: the turn jumps straight to the seat that couldn't answer, skipping the seats that auto-stacked
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
        turnActions.append(.draw(card))
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
        turnActions.append(.play(card, fromIndex: index)) //index so the receiver animates it from the same slot
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
            if is1v1 {
                //1v1: the draw-two card stacks (Crazy 8s 2, Mau-Mau 7, Switch 2). The opponent can bounce
                //the penalty back with a draw-two of their own, and so on, until someone can't answer;
                //that player draws 2 cards per draw-two played.
                Task { @MainActor in
                    await resolveStackingTwos()
                }
            } else {
                //Group chat: the draw-two cascades forward. Each seat that holds a draw-two auto-plays it,
                //passing the growing penalty to the next seat, until we reach a seat that can't answer —
                //they draw the whole stack and the turn jumps straight to them, skipping the seats between.
                Task { @MainActor in
                    await resolveStackingTwosGroup()
                }
            }
        } else if variant == .irishSwitch && card.isSwitchJack {
            //Switch: a switch jack (J♠/J♣) forces five cards on the opponent — unless they hold a red jack (J♥/J♦), which cancels it.
            GameCenterManager.shared.report(achievement: .discardTwo)
            activeSuitOverride = nil
            if is1v1, !playerHand.isEmpty, let redJackIndex = opponentHand.firstIndex(where: { $0.isRedJack }) {
                let redJack = opponentHand[redJackIndex]
                //The opponent auto-plays their red jack to cancel. That counts as their turn, so we
                //DON'T send — the turn returns to the local player, mirroring the queen-skip flow above.
                //Block interaction and animate the counter: opponentCardAnimatingToDiscard drives the
                //fly-to-discard (opponentDiscardCard commits it when it lands), then we hand control back
                //to the local player for their bonus turn.
                phase = .animationPhase
                turnActions.append(.counterPlay(redJack, fromIndex: redJackIndex)) //the next player auto-plays their red jack; replayed from their hand slot
                switchCountersThisTurn.append(SwitchCounter(switchJack: card, redJack: redJack)) //legacy compat: lets pre-refactor clients replay the exchange
                _ = recordLocalTurn()
                cardsDrawnThisTurn = 0
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 400_000_000) //let the player's switch jack land first
                    opponentCardAnimatingToDiscard = redJack
                    try? await Task.sleep(nanoseconds: 800_000_000) //let the red-jack counter land
                    if phase == .animationPhase {
                        phase = .mainPhase //hand control back to the local player for their bonus turn
                        checkHandPlayability()
                    }
                }
            } else {
                //No red jack to cancel with (or a group chat): force the five-card penalty as normal.
                phase = .animationPhase
                Task { @MainActor in
                    await dealPenaltyCards(count: 5)
                    completeTurn()
                }
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
        } else if card.rank == variant.playAgainRank {
            //Pesten "sticky seven": play a 7 and immediately go again. Like the 1v1 skip bonus, this
            //keeps the turn local in both 1v1 and group chat — we don't send, so the turn never passes.
            //The accumulated turnActions replay the whole bonus sequence to the next player verbatim.
            activeSuitOverride = nil
            if !playerHand.isEmpty {
                _ = recordLocalTurn()
                cardsDrawnThisTurn = 0
                checkHandPlayability()
            } else {
                completeTurn() //played their last card on the seven — completeTurn handles the win + send
            }
        } else {
            activeSuitOverride = nil
            completeTurn()
        }
    }

    @MainActor
    private func dealPenaltyCards(count: Int, toSeat: Int? = nil) async {
        //In V2 3+ player, swap the active opponent slot to the penalized seat so the penalty draws animate into their hand.
        let isMultiOpponent = !is1v1 && seats.count > 2
        let step = isDirectionReversed ? -1 : 1
        let computedNext = seats.isEmpty ? 0 : ((mySeatIndex + step) % seats.count + seats.count) % seats.count
        let targetSeat = toSeat ?? computedNext

        if isMultiOpponent {
            //commit whatever hand is currently animating before switching the active slot (the cascade may
            //have left a stacking seat active), then bring the penalized seat's hand up to animate into it.
            if allHands.indices.contains(animatingOpponentSeat) { allHands[animatingOpponentSeat] = opponentHand }
            animatingOpponentSeat = targetSeat
            opponentHand = allHands.indices.contains(targetSeat) ? allHands[targetSeat] : []
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
            if isMultiOpponent, allHands.indices.contains(targetSeat) {
                allHands[targetSeat].append(drawn)
            }
            opponentCardAnimatingFromDeck = drawn
            turnActions.append(.forceDraw(drawn)) //forced onto the next player; replayed into their hand
            penaltyCardsForcedOnOpponent += 1
            try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s, matches opponent draw cadence
        }

        if isMultiOpponent {
            //restore opponentHand to the previous opponent's hand so sendV2GameState's previousSeat assignment is a no-op
            opponentHand = allHands.indices.contains(previousPlayerSeatIndex) ? allHands[previousPlayerSeatIndex] : []
        }
    }

    // Stacking draw-twos (1v1, any variant: Crazy 8s 2, Mau-Mau 7, Switch 2). The user has already played
    // one draw-two (recorded as a .play and sitting on the discard). The opponent may answer with a draw-two
    // of their own — auto-played here, bouncing the penalty back — then the user auto-stacks a third if they
    // hold one, and the opponent a fourth, and so on. Whoever can't answer draws 2 cards per draw-two played
    // (2, 4, 6, or 8). The whole exchange runs on the
    // acting player's device and is captured in the action log so the other device replays it verbatim:
    // the opponent's answers as .counterPlay, the user's own stacked 2s as .play, and the loser's draws as
    // .forceDraw (opponent loses → their turn) or .draw (user loses → they keep a bonus turn).
    @MainActor
    private func resolveStackingTwos() async {
        var twosPlayed = 1            // the 2 the user just played
        var opponentToAnswer = true  // the opponent answers the user's 2 first, then it alternates

        while true {
            if opponentToAnswer {
                guard let index = opponentHand.firstIndex(where: { $0.rank == variant.drawTwoRank }) else { break }
                let two = opponentHand[index]
                twosPlayed += 1
                turnActions.append(.counterPlay(two, fromIndex: index)) //opponent auto-answers from their hand slot
                try? await Task.sleep(nanoseconds: 400_000_000) //let the previous card land first
                opponentCardAnimatingToDiscard = two //opponentDiscardCard commits & removes it on landing
                try? await Task.sleep(nanoseconds: 800_000_000)
                if isGameOver { break } //opponent emptied their hand answering with their last 2
            } else {
                guard let index = playerHand.firstIndex(where: { $0.rank == variant.drawTwoRank }) else { break }
                let two = playerHand.remove(at: index)
                discardPile.append(two)
                turnActions.append(.play(two, fromIndex: index))
                twosPlayed += 1
                SoundManager.instance.playCardSlap()
                HapticManager.instance.playCardSlap()
                try? await Task.sleep(nanoseconds: 600_000_000)
                if playerHand.isEmpty { playerHasWon = true; break } //user stacked their last card
            }
            opponentToAnswer.toggle()
        }

        if isGameOver {
            //opponent emptied their hand answering — they win. Send the final state; keep the game-over UI.
            sendGameStateSwitch()
            return
        }
        if playerHasWon {
            completeTurn() //user emptied their hand stacking their last 2; completeTurn handles the win + send
            return
        }

        let penalty = twosPlayed * 2
        if opponentToAnswer {
            //loop ended waiting on the OPPONENT → they couldn't answer, so they draw and the turn passes to them
            await dealPenaltyCards(count: penalty)
            completeTurn()
        } else {
            //loop ended waiting on the USER → they couldn't answer, so they draw and keep the turn (bonus play)
            await dealPenaltyCardsToSelf(count: penalty)
            _ = recordLocalTurn()
            cardsDrawnThisTurn = 0
            if phase == .animationPhase {
                phase = .mainPhase
                checkHandPlayability()
            }
        }
    }

    // Stacking draw-twos (group chat). The user has already played one draw-two (recorded as a .play,
    // sitting on the discard). The penalty cascades forward: each following seat that holds a draw-two
    // auto-plays it — recorded as a .seatPlay so the receiver replays it from that seat's arc position —
    // passing the growing stack to the next seat, until we reach a seat that can't answer. That seat draws
    // the whole stack (2 cards per draw-two played) and the turn jumps straight to them, skipping the seats
    // that auto-stacked. If every other seat answers, the stack wraps back to the original player, who
    // draws it and keeps their turn (a bonus play, mirroring the 1v1 self-draw). The entire cascade runs on
    // the acting player's device and is captured in the action log so every other device replays it verbatim.
    @MainActor
    private func resolveStackingTwosGroup() async {
        guard seats.count > 1 else { completeTurn(); return }
        var twosPlayed = 1 // the draw-two the user just played
        let step = isDirectionReversed ? -1 : 1
        var seat = ((mySeatIndex + step) % seats.count + seats.count) % seats.count
        var seatsChecked = 0 // safety bound: never revisit the acting player, even if the whole table stacks

        while seatsChecked < seats.count - 1 {
            guard allHands.indices.contains(seat),
                  let index = allHands[seat].firstIndex(where: { $0.rank == variant.drawTwoRank }) else { break }
            let two = allHands[seat][index]

            // Switch the active opponent to this seat and animate their forced auto-play.
            if allHands.indices.contains(animatingOpponentSeat) { allHands[animatingOpponentSeat] = opponentHand }
            animatingOpponentSeat = seat
            opponentHand = allHands[seat]
            turnActions.append(.seatPlay(two, fromIndex: index, seat: seat))
            try? await Task.sleep(nanoseconds: 400_000_000) // let the arc reposition to this seat
            opponentCardAnimatingToDiscard = two             // opponentDiscardCard commits & removes it on landing
            try? await Task.sleep(nanoseconds: 800_000_000)
            allHands[seat] = opponentHand                    // reflect the played card back into the seat's hand
            twosPlayed += 1

            if isGameOver {
                //this seat emptied their hand on the forced play — they win. Stop the cascade and pass the
                //turn onward normally so every device detects the win (winner via empty hand, others via animation).
                overrideNextSeat = ((seat + step) % seats.count + seats.count) % seats.count
                sendGameStateSwitch()
                return
            }

            seat = ((seat + step) % seats.count + seats.count) % seats.count
            seatsChecked += 1
        }

        let penalty = twosPlayed * 2
        if seat == mySeatIndex {
            //Every other seat answered — the stack wraps back to the original player, who draws it and keeps
            //the turn (bonus play). Like the 1v1 self-draw, this keeps the turn local; we don't send here.
            await dealPenaltyCardsToSelf(count: penalty)
            _ = recordLocalTurn()
            cardsDrawnThisTurn = 0
            if phase == .animationPhase {
                phase = .mainPhase
                checkHandPlayability()
            }
        } else {
            //`seat` couldn't answer: they draw the whole stack and the turn jumps straight to them.
            overrideNextSeat = seat
            await dealPenaltyCards(count: penalty, toSeat: seat)
            completeTurn()
        }
    }

    //Draw a stacked draw-two penalty into the local player's own hand (1v1). Mirrors dealPenaltyCards but
    //the forced cards land locally and are recorded as .draw actions, so the opponent replays them as the
    //acting player drawing from the deck. Appending each card animates it in via the player hand view.
    @MainActor
    private func dealPenaltyCardsToSelf(count: Int) async {
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
            playerHand.append(drawn)
            turnActions.append(.draw(drawn)) //acting player drew; replayed as the opponent drawing on the other device
            try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s, matches draw cadence
        }
    }

    func userDrawPenaltyCard() {
        guard pendingPlayerPenaltyDraws > 0 else { return }
        if deck.isEmpty { return } //deck should already contain the rewound penalty cards from prepareAnimation
        let card = deck.popLast()!
        playerHand.append(card)
        pendingPlayerPenaltyDraws -= 1
    }

    func submitChosenSuit(_ suit: Suit) {
        activeSuitOverride = suit
        turnActions.append(.chooseSuit(suit))
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

    //Commit one played card to the discard as its fly-to-discard animation lands. Called per `.play`
    //action; the phase transition is owned by animateOpponentsTurn once the whole log is replayed.
    func opponentDiscardCard(card: Card) { //pseudo discard
        guard phase == .animationPhase || isAnimatingOpponentTurn else { return }

        //Remove the exact card that animated (usually the last in the replay path, but a Switch
        //red-jack counter can sit anywhere in the hand). Fall back to removeLast for safety.
        if let index = opponentHand.firstIndex(of: card) {
            opponentHand.remove(at: index)
        } else {
            opponentHand.removeLast()
        }
        //Keep the active seat's stored hand in sync so it renders correctly once it goes static again
        //(matters during a group-chat draw-two stack, where the active arc slot hops between seats).
        if !is1v1, allHands.indices.contains(animatingOpponentSeat) {
            allHands[animatingOpponentSeat] = opponentHand
        }
        discardPile.append(card)
        // Record the discarding opponent's back so the discard pile can cross-fade this card's front
        // from their theme into the local player's theme as their turn ends.
        discardCrossfadeFromBack = cardBack(forSeat: animatingOpponentSeat) // 1v1 handled inside
        SoundManager.instance.playCardSlap()
        HapticManager.instance.playCardSlap()

        opponentHasWon = opponentHand.isEmpty
        if opponentHasWon {
            SoundManager.instance.playGameEnd(didWin: false)
            isAnimatingOpponentTurn = false
            phase = .gameEndPhase
            isGameOver = true
        }
    }

    //Switch: commit the local player's auto-played red jack when its counter animation lands.
    //Mirrors opponentDiscardCard but for the player's own hand; phase advancement stays with the
    //opponent's final-card discard (or the pass-case cleanup) in animateOpponentsTurn.
    func playerAutoDiscardLanded(card: Card) {
        guard phase == .animationPhase || isAnimatingOpponentTurn else { return }
        if let index = playerHand.firstIndex(of: card) {
            playerHand.remove(at: index)
        }
        discardPile.append(card)
        SoundManager.instance.playCardSlap()
        HapticManager.instance.playCardSlap()
    }

    //Group-chat draw-two stack replay: bring a stacking seat's hand up as the active arc hand so its
    //auto-played draw-two can fly to the discard, mirroring what the sender animated. opponentDiscardCard
    //commits the card (and syncs allHands) once it lands.
    func beginSeatPlayAnimation(forSeat seat: Int) {
        guard phase == .animationPhase || isAnimatingOpponentTurn else { return }
        animatingOpponentSeat = seat
        opponentHand = allHands.indices.contains(seat) ? allHands[seat] : []
    }

    //Return the active arc slot to the acting player after a draw-two stack moved it onto a stacking seat.
    //Needed only for the rare wrap-around, where the stack circles the whole table back to the acting
    //player and their own follow-up draws/plays must animate from their seat again. Returns true when it
    //actually switched, so the caller can wait for the arc to reposition.
    @discardableResult
    func restoreActingSeatIfNeeded(_ seat: Int) -> Bool {
        guard phase == .animationPhase || isAnimatingOpponentTurn else { return false }
        guard animatingOpponentSeat != seat else { return false }
        if allHands.indices.contains(animatingOpponentSeat) { allHands[animatingOpponentSeat] = opponentHand }
        animatingOpponentSeat = seat
        opponentHand = allHands.indices.contains(seat) ? allHands[seat] : []
        return true
    }

    //Commit a stacking seat's auto-play with no arc animation. Used when that seat is the local player's
    //own (a spectator who was part of the stack): their seat isn't drawn in the opponent arc, so there's
    //no hand to fly the card from — we just drop it onto the discard.
    func commitSeatPlayWithoutAnimation(_ card: Card) {
        guard phase == .animationPhase || isAnimatingOpponentTurn else { return }
        discardPile.append(card)
        SoundManager.instance.playCardSlap()
        HapticManager.instance.playCardSlap()
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
        self.turnActions = []
        self.actionsToAnimate = []
        self.opponentDidDiscard = state.didDiscard
        //hiddenActiveSuitOverride is the authoritative post-turn suit; the animation reveals it at the
        //end (and earlier on a .chooseSuit action). When the opponent didn't discard there's no discard
        //animation, so show it immediately.
        self.hiddenActiveSuitOverride = state.activeSuitOverride
        if !opponentDidDiscard {
            self.activeSuitOverride = state.activeSuitOverride
        }

        if isPlayersTurn { //the user is beginning their turn...
            self.playerHand = state.receiverHand
            let hasVisualsToAnimate = prepareAnimation(log: state.turnActions ?? [], opponentPostTurnHand: state.senderHand, localIsPenaltyRecipient: true)
            if hasVisualsToAnimate {
                phase = .animationPhase
            } else { //first turn, or a pre-refactor sender (snap to the final state)
                self.activeSuitOverride = state.activeSuitOverride
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
        self.turnActions = []
        self.actionsToAnimate = []
        self.opponentDidDiscard = state.lastPlayerDidDiscard
        self.hiddenActiveSuitOverride = state.activeSuitOverride
        if !opponentDidDiscard {
            self.activeSuitOverride = state.activeSuitOverride
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
            let hasVisualsToAnimate = prepareAnimation(log: state.turnActions ?? [], opponentPostTurnHand: state.hands[actualPreviousPlayer], localIsPenaltyRecipient: true)
            if hasVisualsToAnimate {
                phase = .animationPhase
            } else { //first turn, or a pre-refactor sender (snap to the final state)
                self.activeSuitOverride = state.activeSuitOverride
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
                //spectator: penalty cards go to a third seat, so they aren't a local-hand animation
                let hasVisualsToAnimate = prepareAnimation(log: state.turnActions ?? [], opponentPostTurnHand: state.hands[actualPreviousPlayer], localIsPenaltyRecipient: false)
                if !hasVisualsToAnimate { self.activeSuitOverride = state.activeSuitOverride }
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
        self.userDidDiscard = false
        self.opponentDidDiscard = false
        self.playerHasWon = false
        self.opponentHasWon = false
        self.isGameOver = false
        self.actionsToAnimate = []
        self.turnActions = []
        self.playerCardAnimatingToDiscard = nil
        self.switchCountersThisTurn = []
        self.opponentCardAnimatingToDiscard = nil
        self.opponentCardAnimatingFromDeck = nil
        self.discardCrossfadeFromBack = nil
        self.penaltyCardsForcedOnOpponent = 0
        self.pendingPlayerPenaltyDraws = 0
        self.deckShouldShowPlayerBack = false
        self.skipNextSeat = false
        self.overrideNextSeat = nil
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

    // Reconstruct the pre-turn board from the received (post-turn) state plus the chronological action
    // log, so the previous player's turn can be replayed forward with animation. Walks `actionsToAnimate`
    // in reverse, applying the exact inverse of each action; because each action is invertible, the
    // board round-trips back to the authoritative post-turn state once the forward replay completes.
    //
    // On entry, playerHand/deck/discardPile must hold the authoritative post-turn board, and
    // `opponentPostTurnHand` is the previous player's authoritative hand. Returns false (→ snap, no
    // animation) when there's no log (a pre-refactor sender) or the discard pile no longer matches the
    // log (a mid-turn reshuffle displaced the played cards — resolve statically).
    //
    // `localIsPenaltyRecipient` is true when forced (penalty) cards land in the local player's hand.
    // For a V2 spectator watching a third seat get penalized, the forced cards are dropped from the
    // script and rendered statically via `allHands`.
    private func prepareAnimation(log: [Crazy8sTurnAction], opponentPostTurnHand: [Card], localIsPenaltyRecipient: Bool) -> Bool {
        /*print("=== prepareAnimation: \(log.count) action(s) ===")
        for (i, action) in log.enumerated() {
            print("  [\(i)] \(action)")
        }*/

        self.opponentHand = opponentPostTurnHand
        self.pendingPlayerPenaltyDraws = 0
        self.actionsToAnimate = [] //only populated below if there's actually a turn to replay

        var actions = log
        if !localIsPenaltyRecipient {
            actions.removeAll { if case .forceDraw = $0 { return true } else { return false } }
        }
        guard !actions.isEmpty else { return false }

        // The cards that must currently sit on top of the discard, oldest→newest, are exactly the
        // played/countered cards from the log. If a reshuffle displaced them, replay isn't safe.
        let playedOntoDiscard: [Card] = actions.compactMap { action in
            switch action {
            case .play(let c, _), .counterPlay(let c, _), .seatPlay(let c, _, _): return c
            default: return nil
            }
        }
        guard discardPile.count >= playedOntoDiscard.count,
              Array(discardPile.suffix(playedOntoDiscard.count)) == playedOntoDiscard else {
            return false //resolve statically: keep the authoritative board, skip animation
        }

        // Undo each action in reverse to rewind the board to its pre-turn positions. Deck-sourced cards
        // (draws, forced draws) are appended back in reverse order so the forward replay pops them in the
        // original order; played cards are peeled off the discard top and re-inserted at the hand slot they
        // were played from, so the forward replay animates each one leaving its original position.
        for action in actions.reversed() {
            switch action {
            case .draw(let card):
                if let i = opponentHand.firstIndex(of: card) { opponentHand.remove(at: i); deck.append(card) }
            case .play(let card, let fromIndex):
                discardPile.removeLast()
                opponentHand.insert(card, at: min(fromIndex, opponentHand.count))
            case .forceDraw(let card):
                if let i = playerHand.firstIndex(of: card) { playerHand.remove(at: i); deck.append(card) }
            case .counterPlay(let card, let fromIndex):
                discardPile.removeLast()
                playerHand.insert(card, at: min(fromIndex, playerHand.count))
            case .seatPlay(let card, let fromIndex, let seat):
                //rewind a stacking seat's auto-play: peel it off the discard and return it to that seat's
                //hand. For the local player's OWN past auto-play (spectator watching a stack they were part
                //of), there's no arc slot to animate from, so we only rewind the discard and re-commit it
                //statically during the forward replay.
                discardPile.removeLast()
                if seat != mySeatIndex, allHands.indices.contains(seat) {
                    allHands[seat].insert(card, at: min(fromIndex, allHands[seat].count))
                }
            case .chooseSuit:
                break //no positional change; the suit reveals during forward replay
            }
        }

        // The penalty animation draws forced cards from the deck into the local player's hand.
        pendingPlayerPenaltyDraws = actions.reduce(0) { count, action in
            if case .forceDraw = action { return count + 1 } else { return count }
        }

        // Keep the V2 allHands mirror of the rewound local hand in sync (unused by the local hand's own
        // render, but keeps spectator/static state consistent).
        if !is1v1, allHands.indices.contains(mySeatIndex) {
            allHands[mySeatIndex] = playerHand
        }
        self.actionsToAnimate = actions //the (filtered) script the orchestrator will replay
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
                variant: variant,
                switchCounters: nil,
                turnActions: nil
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
                variant: variant,
                turnActions: nil
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
            variant: state.variant,
            turnActions: nil)

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
            variant: variant,
            switchCounters: switchCountersThisTurn.isEmpty ? nil : switchCountersThisTurn,
            turnActions: turnActions.isEmpty ? nil : turnActions
        )

        guard let stateData = try? JSONEncoder().encode(currentGameState) else {
            print("Error: Failed to encode Crazy8sGameState into Data.")
            return
        }

        self.switchCountersThisTurn = [] //consumed for this outgoing turn
        self.turnActions = []            //consumed for this outgoing turn
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

        //A draw-two stack jumps the turn straight to the seat that couldn't answer; otherwise skipNextSeat
        //advances by 2 (queen skip) and direction follows the ace-toggled flag.
        let step = isDirectionReversed ? -1 : 1
        let advancement = (skipNextSeat ? 2 : 1) * step
        let nextSeat = overrideNextSeat ?? ((mySeatIndex + advancement) % seats.count + seats.count) % seats.count

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
            variant: variant,
            turnActions: turnActions.isEmpty ? nil : turnActions
        )

        guard let stateData = try? JSONEncoder().encode(currentGameState) else {
            print("Error: Failed to encode Crazy8sGameStateV2 into Data.")
            return
        }

        self.turnActions = [] //consumed for this outgoing turn
        self.turnNumber += 1
        // Mark our seat as the one who just played so the deck immediately reflects the next player's back.
        self.seatCardBacks = outgoingBacks
        self.animatingOpponentSeat = mySeatIndex
        self.skipNextSeat = false
        self.overrideNextSeat = nil
        //Defer the iMessage send to the next runloop so SwiftUI commits the discard state change first.
        Task { @MainActor [weak self] in
            self?.onTurnCompleted?(stateData, .crazy8s)
        }
    }

}

// Switch helpers: the pick-up-5 is triggered by the switch jacks and cancelled by a red jack.
private extension Card {
    var isSwitchJack: Bool { rank == .jack && (suit == .spades || suit == .clubs) }
    var isRedJack: Bool { rank == .jack && (suit == .hearts || suit == .diamonds) }
}
