//
//  WinTracker.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 4/25/26.
//

import Messages

class WinTracker {
    static let shared = WinTracker()
    private let legacyGinKey = "ginWins" // <- set for deprecation on a later update
    
    private func key(for gameTitle: String) -> String {
        return "\(gameTitle.lowercased().replacingOccurrences(of: " ", with: "_"))_wins"
    }

    func getWinCount(for gameTitle: String) -> Int {
        //MIGRATING OLD GIN WIN KEY TO NEW GIN WIN KEY
        let newKey = key(for: gameTitle)
        let defaults = UserDefaults.standard
        if gameTitle == "Gin Rummy" && defaults.object(forKey: newKey) == nil {
            let legacyWins = defaults.integer(forKey: legacyGinKey)
            if legacyWins > 0 {
                // Move the data to the new key
                defaults.set(legacyWins, forKey: newKey)
                // Remove the old key so we don't migrate again
                defaults.removeObject(forKey: legacyGinKey)
                return legacyWins
            }
        }
        
        return UserDefaults.standard.integer(forKey: key(for: gameTitle))
    }
    
    func incrementWins(for gameTitle: String) {
        let currentWins = getWinCount(for: gameTitle)
        UserDefaults.standard.set(currentWins + 1, forKey: key(for: gameTitle))
    }

    func recordWinOnce(for gameTitle: String, sessionID: UUID) {
        let key = "\(key(for: gameTitle))_counted_\(sessionID.uuidString)"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        incrementWins(for: gameTitle)
    }

    var totalWins: Int {
        let gameTitles = ["Gin Rummy", "Crazy 8s", "Golf"]
        return gameTitles.reduce(0) { $0 + getWinCount(for: $1) }
    }
}
