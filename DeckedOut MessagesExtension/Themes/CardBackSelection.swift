//
//  CardBackSelection.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 5/19/26.
//

import SwiftUI

final class CardBackSelection: ObservableObject {
    static let shared = CardBackSelection()
    static let defaultName = "cardBackRed"
    private let storageKey = "selected_card_back"

    @Published var selectedName: String {
        didSet {
            UserDefaults.standard.set(selectedName, forKey: storageKey)
        }
    }

    /// The "Base" image used for letter cards. Falls back to `selectedName` when no `…Base` asset exists.
    var baseName: String {
        let candidate = selectedName + "Base"
        return UIImage(named: candidate) != nil ? candidate : selectedName
    }

    /// Accent color of the currently selected theme. Falls back to `salmonRed` if the
    /// stored card-back name doesn't match a known theme (e.g. a removed/renamed asset).
    var selectedColor: Color {
        return CardBackTheme.theme(forLogoCard: selectedName)?.primaryColor ?? Palette.salmonRed
    }
    
    var textColor: Color {
        return CardBackTheme.theme(forLogoCard: selectedName)?.secondaryColor ?? Color(.white)
    }

    private init() {
        self.selectedName = UserDefaults.standard.string(forKey: storageKey) ?? Self.defaultName
    }
}
