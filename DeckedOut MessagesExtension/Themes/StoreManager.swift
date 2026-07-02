//
//  StoreManager.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 5/20/26.
//

import Foundation
import StoreKit

@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()

    @Published private(set) var products: [String: Product] = [:]
    @Published private(set) var ownedProductIDs: Set<String> = []
    @Published private(set) var purchaseInFlight: String? = nil // productID currently being purchased, if any
    /// The App Store storefront's country, as an ISO 3166-1 *alpha-3* code (e.g. `"AUS"`). `nil` until
    /// `start()` has resolved the storefront. Used as an additional signal for region-gated themes.
    @Published private(set) var storefrontCountryCode: String? = nil

    /// Non-consumable IAP that grants every other paid IAP.
    static let masterUnlockProductID = "Sawyer.DeckedOut.MasterUnlock"
    var ownsMasterUnlock: Bool { ownedProductIDs.contains(Self.masterUnlockProductID) }

    private var updatesTask: Task<Void, Never>?
    private var hasStarted = false

    private init() {}

    /// Idempotent: starts the transaction listener and loads products + entitlements.
    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        if let storefront = await Storefront.current {
            storefrontCountryCode = storefront.countryCode
        }
        updatesTask = listenForTransactions()
        await loadProducts()
        await refreshEntitlements()
    }

    func loadProducts() async {
        let ids = DeckTheme.all.compactMap(\.productID)
        guard !ids.isEmpty else { return }
        do {
            let fetched = try await Product.products(for: ids)
            products = Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) })
        } catch {
            // Network unavailable, sandbox not signed in, etc. UI falls back to "—".
        }
    }

    func refreshEntitlements() async {
        var owned: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                owned.insert(transaction.productID)
            }
        }
        ownedProductIDs = owned
    }

    /// Returns true if the purchase completed (or was already owned). False on cancel/pending/failure.
    @discardableResult
    func purchase(_ productID: String) async -> Bool {
        if isOwned(productID) { return true }
        guard let product = products[productID] else { return false }

        purchaseInFlight = productID
        defer { purchaseInFlight = nil }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    ownedProductIDs.insert(transaction.productID)
                    await transaction.finish()
                    return true
                }
                return false
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            return false
        }
    }

    /// Required for non-consumable IAPs. Wire up to a "Restore Purchases" button.
    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    /// Convenience: free themes (productID == nil) always count as owned.
    /// Owning the master-unlock IAP also counts as owning any individual paid IAP.
    func isOwned(_ productID: String?) -> Bool {
        guard let id = productID else { return true }
        if ownsMasterUnlock { return true }
        return ownedProductIDs.contains(id)
    }

    /// True only if this exact IAP was purchased directly — master unlock does NOT count.
    /// Used to keep a region-gated flag visible after the player leaves that region: only a flag
    /// they truly bought should follow them abroad. Master-unlock owners see out-of-region flags
    /// only while they're in that region (and equip them free via `isOwned`).
    func directlyOwns(_ productID: String?) -> Bool {
        guard let id = productID else { return true }
        return ownedProductIDs.contains(id)
    }

    /// Localized price for a product ID, or nil if products haven't loaded yet or IAPs are disabled.
    func displayPrice(for productID: String) -> String? {
        //guard let product = products[productID] else { return nil}
            
        // Reformat $1.00 -> $1
        //return product.price.formatted(
        //    product.priceFormatStyle.precision(.fractionLength(0...2))
        //)
        return products[productID]?.displayPrice
    }

    private func listenForTransactions() -> Task<Void, Never> {
        return Task { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                self?.ownedProductIDs.insert(transaction.productID)
                await transaction.finish()
            }
        }
    }
}
