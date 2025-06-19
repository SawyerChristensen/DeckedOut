import Foundation

enum Suit: String, CaseIterable {
    case spades = "♠️"
    case hearts = "♥️"
    case diamonds = "♦️"
    case clubs = "♣️"
}

enum Rank: Int, CaseIterable {
    case two = 2, three, four, five, six, seven, eight, nine, ten
    case jack, queen, king, ace

    var stringValue: String {
        switch self {
        case .jack: return "J"
        case .queen: return "Q"
        case .king: return "K"
        case .ace: return "A"
        default: return "\(rawValue)"
        }
    }
}

struct Card: Identifiable {
    let id = UUID()
    let suit: Suit
    let rank: Rank
} 