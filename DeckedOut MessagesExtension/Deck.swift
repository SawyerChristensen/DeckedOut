import Foundation

struct Deck {
    private var cards: [Card]

    init() {
        self.cards = []
        for suit in Suit.allCases {
            for rank in Rank.allCases {
                cards.append(Card(suit: suit, rank: rank))
            }
        }
        shuffle()
    }

    mutating func shuffle() {
        cards.shuffle()
    }
    
    mutating func drawCard() -> Card? {
        return cards.isEmpty ? nil : cards.removeFirst()
    }
}

/// Represents a single card.
struct Card: Hashable { //to do later: refactor logic switching rank & suit in card construction but this is largely a cosmetic choice
    public let suit: Suit
    public let rank: Rank
    
    public init(suit: Suit, rank: Rank) {
        self.suit = suit
        self.rank = rank
    }
}

/// Represents a standard playing card suit.
public enum Suit: Int, CaseIterable { /// CaseIterable lets us loop through all suits easily.
    case spades = 0
    case hearts = 1
    case diamonds = 2
    case clubs = 3
}

/// Represents a standard playing card rank (Ace low).
public enum Rank: Int, CaseIterable { // note the values are 0 indexed!
    case ace = 0
    case two = 1
    case three = 2
    case four = 3
    case five = 4
    case six = 5
    case seven = 6
    case eight = 7
    case nine = 8
    case ten = 9
    case jack = 10
    case queen = 11
    case king = 12
}
