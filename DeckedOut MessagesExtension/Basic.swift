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
    case spades, hearts, diamonds, clubs // 0, 1, 2, 3
    
    var stringValue: String { //used in the backend to fetch image names (see struct Card)
        switch self {
        case .spades: return "Spades"
        case .hearts: return "Hearts"
        case .diamonds: return "Diamonds"
        case .clubs: return "Clubs"
        }
    }
    
    var localizedName: String { //user facing text in message summaries
        switch self {
        case .spades:   return String(localized: "Spades", comment: "Card suit: Spades")
        case .hearts:   return String(localized: "Hearts", comment: "Card suit: Hearts")
        case .diamonds: return String(localized: "Diamonds", comment: "Card suit: Diamonds")
        case .clubs:    return String(localized: "Clubs", comment: "Card suit: Clubs")
        }
    }
}


///Ace is treated as a low card here! Might want to change later depending on game!
public enum Rank: Int, CaseIterable, Codable { // note the values are 0 indexed! they do not match their english values!
    case ace, two, three, four, five, six, seven, eight, nine, ten, jack, queen, king // ace = 0, two = 1, three = 2...
    
    var stringValue: String { //used in the backend to fetch image names (see struct Card)
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
    
    var localizedName: String { //user facing text in message summaries
        switch self {
        case .ace:   return String(localized: "Ace", comment: "Card rank: Ace")
        case .jack:  return String(localized: "Jack", comment: "Card rank: Jack")
        case .queen: return String(localized: "Queen", comment: "Card rank: Queen")
        case .king:  return String(localized: "King", comment: "Card rank: King")
        default:
            // for 2-10, we just return the number. Numbers dont need to be translated
            return String(self.rawValue + 1)
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
        return cards.popLast()
    }*/
}
