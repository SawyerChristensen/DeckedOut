//
//  SharedEntitlements.swift
//  DeckedOut
//
//  Bridges deck-theme IAP ownership between DeckedOut and PocketPoker.
//
//  App Store Connect has no way to share an IAP product record across two app records, so a theme
//  bought in one app is invisible to the other's `Transaction.currentEntitlements`. This file is the
//  bridge: each app publishes the set of themes it owns into two stores that both apps can read.
//
//    • App Group container — covers "both apps installed on this device". Instant, offline.
//    • NSUbiquitousKeyValueStore — covers "same iCloud account, other device" and "sister app not
//      installed here". Free, no backend, eventually consistent.
//
//  Storage shape is a dictionary of per-app *snapshots*, not one merged set:
//
//      ["PocketPoker": ["Theme.Koi"], "DeckedOut": ["Theme.Koi", "Theme.Web"]]
//
//  Each app overwrites only its own bucket, with whatever StoreKit currently reports. That makes
//  refunds self-healing — a refund in DeckedOut shrinks DeckedOut's bucket on its next launch, and
//  this app's view narrows with it. A flat additive set would grant refunded themes forever.
//
//  REQUIRES (all four targets across both projects): the App Groups capability for
//  `SharedEntitlements.appGroupID`, and the iCloud capability with Key-value storage where
//  `com.apple.developer.ubiquity-kvstore-identifier` is hand-edited to the SAME string in both apps
//  (Xcode defaults it per-bundle-ID, which would keep the two stores separate).
//
//  Not tamper-proof — both stores are user-writable on a jailbroken device. Fine for $1 cosmetics.
//

import Foundation

enum SharedEntitlements {

    /// Shared App Group container, registered on both apps and both Messages extensions.
    static let appGroupID = "group.Sawyer.CardGameApps"

    /// This app's bucket. The sister app uses "PocketPoker".
    static let appKey = "DeckedOut"

    private static let storeKey = "sharedThemeEntitlements"

    // MARK: - Canonical IDs

    /// Product IDs are `Sawyer.<App>.<Canonical>`, so dropping the first two components yields a
    /// name both apps agree on: `Sawyer.DeckedOut.Theme.Koi` -> `Theme.Koi`, and
    /// `Sawyer.DeckedOut.MasterUnlock` -> `MasterUnlock`.
    static func canonical(_ productID: String) -> String {
        productID.split(separator: ".").dropFirst(2).joined(separator: ".")
    }

    /// Canonical form of the master-unlock IAP, for cross-app master-unlock checks.
    static let masterUnlockCanonical = "MasterUnlock"

    // MARK: - Stores

    private static let groupDefaults = UserDefaults(suiteName: appGroupID)
    private static var cloud: NSUbiquitousKeyValueStore { .default }

    private static func buckets(_ raw: [String: Any]?) -> [String: Set<String>] {
        guard let raw else { return [:] }
        return raw.reduce(into: [:]) { result, pair in
            if let ids = pair.value as? [String] { result[pair.key] = Set(ids) }
        }
    }

    private static func encode(_ buckets: [String: Set<String>]) -> [String: [String]] {
        buckets.mapValues { $0.sorted() }
    }

    // MARK: - Publish / read

    /// Overwrite this app's bucket in both stores with StoreKit's authoritative set.
    /// Safe to call on every entitlement refresh; it's a couple of small plist writes.
    static func publish(localProductIDs: Set<String>) {
        let mine = Set(localProductIDs.map(canonical))

        var local = buckets(groupDefaults?.dictionary(forKey: storeKey))
        if local[appKey] != mine {
            local[appKey] = mine
            groupDefaults?.set(encode(local), forKey: storeKey)
        }

        var remote = buckets(cloud.dictionary(forKey: storeKey))
        if remote[appKey] != mine {
            remote[appKey] = mine
            cloud.set(encode(remote), forKey: storeKey)
            cloud.synchronize()
        }
    }

    /// Canonical IDs owned through the *sister* app, from either store.
    ///
    /// Per bucket the App Group copy wins when present: it can only have been written by an app
    /// installed on this device, so it's fresher than iCloud's (which may lag a refund by a sync).
    /// iCloud is the only source for a sister app that isn't installed here at all.
    static func fromSisterApps() -> Set<String> {
        let local = buckets(groupDefaults?.dictionary(forKey: storeKey))
        let remote = buckets(cloud.dictionary(forKey: storeKey))

        var result: Set<String> = []
        for key in Set(local.keys).union(remote.keys) where key != appKey {
            result.formUnion(local[key] ?? remote[key] ?? [])
        }
        return result
    }

    /// Pull down whatever iCloud already has. Cheap; call once at startup.
    static func synchronizeCloud() {
        cloud.synchronize()
    }

}
