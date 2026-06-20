//
//  DeckThemeSelection.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 5/19/26.
//

import SwiftUI

final class DeckThemeSelection: ObservableObject {
    static let shared = DeckThemeSelection()
    static let defaultName = "cardBackRed"
    private let storageKey = "selected_card_back"

    @Published var selectedName: String {
        didSet {
            UserDefaults.standard.set(selectedName, forKey: storageKey)
        }
    }

    /// Resolves a card-back asset name to one that actually exists in this build,
    /// falling back to the default red back when it doesn't. Guards transcript and
    /// game views against blank cards when a peer sends a card-back name from a newer
    /// version — e.g. a theme the recipient won't have until they update.
    static func existingBackName(_ name: String) -> String {
        return UIImage(named: name) != nil ? name : defaultName
    }

    /// The "Base" image used for letter cards. Falls back to `selectedName` when no `…Base` asset exists.
    var baseName: String {
        let candidate = selectedName + "Base"
        return UIImage(named: candidate) != nil ? candidate : selectedName
    }

    /// Resolves the front-card asset name for the currently selected theme. When the theme defines
    /// a `fronts` suffix and the themed asset exists, returns `base + suffix` (e.g. `aceClubsEnchanted`);
    /// otherwise falls back to the default `base` name.
    func frontName(for base: String) -> String {
        guard let suffix = DeckTheme.theme(forLogoCard: selectedName)?.fronts else { return base }
        let themed = base + suffix
        return UIImage(named: themed) != nil ? themed : base
    }

    /// Accent color of the currently selected theme. Falls back to `salmonRed` if the
    /// stored card-back name doesn't match a known theme (e.g. a removed/renamed asset).
    var selectedColor: Color {
        return DeckTheme.theme(forLogoCard: selectedName)?.primaryColor ?? Palette.salmonRed
    }
    
    var textColor: Color {
        return DeckTheme.theme(forLogoCard: selectedName)?.secondaryColor ?? Color(.white)
    }

    private init() {
        self.selectedName = UserDefaults.standard.string(forKey: storageKey) ?? Self.defaultName
    }
}
