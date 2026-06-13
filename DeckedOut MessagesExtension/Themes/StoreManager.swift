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
    @Published private(set) var isChinaStorefront: Bool = false

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
            isChinaStorefront = storefront.countryCode == "CHN"
        }
        guard !isChinaStorefront else { return }
        updatesTask = listenForTransactions()
        await loadProducts()
        await refreshEntitlements()
    }

    func loadProducts() async {
        let ids = CardBackTheme.all.compactMap(\.productID)
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
        if isChinaStorefront { return true }
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
        if isChinaStorefront { return }
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    /// Convenience: free themes (productID == nil) always count as owned.
    /// On the China storefront everything is treated as owned because IAPs are disabled there.
    /// Owning the master-unlock IAP also counts as owning any individual paid IAP.
    func isOwned(_ productID: String?) -> Bool {
        if isChinaStorefront { return true }
        guard let id = productID else { return true }
        if ownsMasterUnlock { return true }
        return ownedProductIDs.contains(id)
    }

    /// Localized price for a product ID, or nil if products haven't loaded yet or IAPs are disabled.
    func displayPrice(for productID: String) -> String? {
        if isChinaStorefront { return nil }
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
