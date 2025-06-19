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
} 