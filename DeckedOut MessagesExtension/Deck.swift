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
    }

    mutating func shuffle() {
        cards.shuffle()
    }
    
    mutating func drawCard() -> Card? {
        return cards.isEmpty ? nil : cards.removeFirst()
    }
}

struct Card: Identifiable {
    let id = UUID()
    let suit: Suit
    let rank: Rank
}

enum Suit: String, CaseIterable {
    case spades = "Spades"
    case hearts = "Hearts"
    case diamonds = "Diamonds"
    case clubs = "Clubs"
}

enum Rank: String, CaseIterable { //having 3 case declarations doesnt matter, you can fit all on one line if needed. this is for readability
    case two = "2", three = "3", four = "4", five = "5", six = "6"
    case seven = "7", eight = "8", nine = "9", ten = "10"
    case jack = "jack", queen = "queen", king = "king", ace = "ace"
}

