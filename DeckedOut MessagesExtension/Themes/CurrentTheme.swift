//
//  CurrentTheme.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 5/19/26.
//

import SwiftUI

final class CurrentTheme: ObservableObject {
    static let shared = CurrentTheme()
    static let defaultName = "cardBackRed"
    private let storageKey = "selected_card_back"

    @Published var selectedName: String {
        didSet {
            UserDefaults.standard.set(selectedName, forKey: storageKey)
        }
    }

    /// Memoizes `UIImage(named:)` existence checks. `UIImage(named:)` decodes the asset on
    /// the main thread, so the validating resolvers below (used in transcript/game views to
    /// guard against peer-sent names from a newer version) would otherwise re-decode on every
    /// SwiftUI layout pass. Resolving each name once keeps the checks off the hot path.
    /// Must be accessed from the main thread, which is the case for all SwiftUI `body` callers.
    private static var assetExistenceCache: [String: Bool] = [:]

    static func imageExists(_ name: String) -> Bool {
        if let cached = assetExistenceCache[name] { return cached }
        let exists = UIImage(named: name) != nil
        assetExistenceCache[name] = exists
        return exists
    }

    /// Resolves a card-back asset name to one that actually exists in this build,
    /// falling back to the default red back when it doesn't. Guards transcript and
    /// game views against blank cards when a peer sends a card-back name from a newer
    /// version — e.g. a theme the recipient won't have until they update.
    static func existingBackName(_ name: String) -> String {
        return imageExists(name) ? name : defaultName
    }

    /// The "Base" image used for letter cards. Falls back to `selectedName` when no `…Base` asset exists.
    var baseName: String {
        let candidate = selectedName + "Base"
        return Self.imageExists(candidate) ? candidate : selectedName
    }

    /// Applies the selected theme's front-card suffix (e.g. `aceClubs` → `aceClubsEnchanted`),
    /// falling back to the un-themed `base` when the theme defines no suffix *or* when the themed
    /// asset doesn't exist in this build. The per-card existence check is memoized by `imageExists`,
    /// so it costs at most one decode per unique name. This lets a theme ship a *partial* set of
    /// custom fronts — e.g. the American Flag theme themes only the jokers and leaves every other
    /// card on the default artwork. Returns `base` when the theme defines no front suffix.
    func themedFrontName(for base: String) -> String {
        guard let suffix = DeckTheme.theme(forLogoCard: selectedName)?.fronts else { return base }
        let themed = base + suffix
        return Self.imageExists(themed) ? themed : base
    }

    /// Resolves the themed front name for `base`, falling back to the default artwork when the
    /// theme defines no front suffix or the themed asset is absent. Equivalent to
    /// `themedFrontName(for:)` — which now validates per card — and kept for untrusted contexts
    /// (transcript/game views that may render a name sent by a newer version).
    func frontName(for base: String) -> String {
        return themedFrontName(for: base)
    }

    /// Accent color of the currently selected theme. Falls back to `salmonRed` if the
    /// stored card-back name doesn't match a known theme (e.g. a removed/renamed asset).
    var selectedColor: Color {
        return DeckTheme.theme(forLogoCard: selectedName)?.rulesColor ?? Palette.salmonRed
    }
    
    var textColor: Color {
        return DeckTheme.theme(forLogoCard: selectedName)?.textColor ?? Color(.white)
    }

    private init() {
        self.selectedName = UserDefaults.standard.string(forKey: storageKey) ?? Self.defaultName
    }
}
