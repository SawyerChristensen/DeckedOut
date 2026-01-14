import Foundation

struct Card: Equatable, Identifiable, Codable { //Codable: needed to encode with JSON and transmit the data. Identifiable for iterating over the cards in fannedHandView (and compressing coadable). Equatable to get the firstIndexOf and for meld checking
    public let suit: Suit
    public let rank: Rank
    var id: Int { return (suit.rawValue * 13) + rank.rawValue}
    var imageName: String {
        "\(rank.stringValue)\(suit.stringValue)"
    }
    
    init(suit: Suit, rank: Rank) {
        self.suit = suit
        self.rank = rank
    }
    
    // Compact Codable
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawId = try container.decode(Int.self)
        
        // Reconstruct from the integer
        guard let s = Suit(rawValue: rawId / 13),
              let r = Rank(rawValue: rawId % 13) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid Card ID")
        }
        self.suit = s
        self.rank = r
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.id)
    }
}

public enum Suit: Int, CaseIterable, Codable { /// CaseIterable lets us loop through all suits easily.
    case spades = 0
    case hearts = 1
    case diamonds = 2
    case clubs = 3
    
    var stringValue: String {
        switch self {
        case .spades: return "Spades"
        case .hearts: return "Hearts"
        case .diamonds: return "Diamonds"
        case .clubs: return "Clubs"
        }
    }
}

///Ace is treated as a low card here! Might want to change later depending on game!
public enum Rank: Int, CaseIterable, Codable { // note the values are 0 indexed!
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
    
    var stringValue: String {
        switch self {
        case .ace: return "ace"
        case .two: return "2"
        case .three: return "3"
        case .four: return "4"
        case .five: return "5"
        case .six: return "6"
        case .seven: return "7"
        case .eight: return "8"
        case .nine: return "9"
        case .ten: return "10"
        case .jack: return "jack"
        case .queen: return "queen"
        case .king: return "king"
        }
    }
}

struct Deck {
    var cards: [Card]

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
    /*
    mutating func drawCard() -> Card? {
        return cards.isEmpty ? nil : cards.removeFirst()
    }*/
}
