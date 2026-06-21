//
//  GameCenterManager.swift
//  DeckedOut MessagesExtension
//
//  Created by Sawyer Christensen on 6/10/26.
//

import Foundation
import GameKit

// To add a new achievement:
//   1. Configure it in App Store Connect (or in the .gccfg Game Center config file in Xcode)
//      under "Achievements". The identifier you set there must match `rawValue` below.
//   2. Add a new case to the `Achievement` enum.
//   3. Call `GameCenterManager.shared.report(.yourAchievement)` (or `.increment(...)`)
//      from wherever the milestone occurs (e.g. a win handler in a GameManager).
//
// Authentication is started once at app launch from `MessagesViewController.setupFeedbackSystems()`
// on a background task so it never blocks boot. If the user isn't already signed into Game Center
// we silently skip — iMessage extensions are too cramped to interrupt with a sign-in sheet.
// Reports made before auth completes are queued and flushed once the player is authenticated.

@MainActor
final class GameCenterManager {
    nonisolated static let shared = GameCenterManager()

    /// Identifiers for every achievement in the app. The `rawValue` must match the achievement identifier configured in App Store Connect exactly.
    enum Achievement: String, CaseIterable {
        // First wins
        case firstWinGin     = "deckedout.first_win.gin"    /// 10 pts
        case firstWinCrazy8s = "deckedout.first_win.crazy8s"/// 10 pts
        case firstWinGolf    = "deckedout.first_win.golf"   /// 10 pts

        // Cumulative win milestones (progress-based, 0–100%)
        case firstWinEver     = "deckedout.wins.total.1"    /// 10 pts
        case twoWinsTotal     = "deckedout.wins.total.2"    /// 20 pts
        case tenWinsTotal     = "deckedout.wins.total.10"   /// 30 pts, Hidden
        case twentyWinsTotal  = "deckedout.wins.total.20"   /// 40 pts, Hidden
        case hundredWinsTotal = "deckedout.wins.total.100"  /// 50 pts, Hidden
        
        // Gin Rummy specific
        case ginMaster = "deckedout.gin.master"             /// Win a game with your entire hand forming a single run (25 pts)
        
        // Crazy 8s specific
        case discardEight  = "deckedout.crazy8s.eight"      /// Discard an 8 (8 points)
        case discardTwo    = "deckedout.crazy8s.two"        /// Discard a 2 (2 points)
        case discardQueen  = "deckedout.crazy8s.queen"      /// Discard a queen (9 points)
        case discardAce    = "deckedout.crazy8s.ace"        /// Discard an ace in a group chat (1 points)
        case crazy8sMaster = "deckedout.crazy8s.master"     /// Win on exactly your 8th personal turn (25 pts)
        
        // Golf specific
        case golfHoleInOne = "deckedout.golf.score0"        /// Win a game of Golf with a final score of 0 (0 points)
        case golfMaster    = "deckedout.golf.master"        /// Win a game of Golf with a hand of only royal cards — jacks, queens, kings (25 pts)
    } ///in hindsight, first win achievements should've been grouped under their respective games, but keys in ASC are immutable

    private(set) var isAuthenticated = false

    /// Achievements we've already loaded or created locally, keyed by identifier.
    /// Cached so we don't regress progress across multiple report calls in one session.
    private var cachedAchievements: [String: GKAchievement] = [:]

    /// Achievements that were reported before authentication finished. Flushed on success.
    private var pendingReports: [String: GKAchievement] = [:]

    private var hasStartedAuthentication = false

    nonisolated private init() {}

    // MARK: - Authentication
    /// Begin authenticating the local player. Safe to call from any thread; the work hops to the main actor. Calling more than once is a no-op.
    nonisolated func authenticate() {
        Task { @MainActor in
            await self.startAuthenticationIfNeeded()
        }
    }

    private func startAuthenticationIfNeeded() async {
        guard !hasStartedAuthentication else { return }
        hasStartedAuthentication = true

        let localPlayer = GKLocalPlayer.local
        localPlayer.authenticateHandler = { [weak self] viewController, error in
            // GameKit invokes this on the main thread.
            MainActor.assumeIsolated {
                self?.handleAuthenticationCallback(viewController: viewController, error: error)
            }
        }
    }

    private func handleAuthenticationCallback(viewController: UIViewController?, error: Error?) {
        // Full visibility into every auth callback: GameKit may call this more than once.
        let player = GKLocalPlayer.local
        print("🎮 [GCAuth] callback fired — isAuthenticated=\(player.isAuthenticated), viewController=\(viewController != nil ? "PRESENT (sign-in UI offered)" : "nil"), error=\(error.map { "\(($0 as NSError).domain) code=\(($0 as NSError).code): \($0.localizedDescription)" } ?? "none")")

        if let error = error {
            let ns = error as NSError
            print("❌ [GCAuth] authentication FAILED — domain=\(ns.domain) code=\(ns.code) — \(ns.localizedDescription)")
            if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError {
                print("   ↳ underlying: domain=\(underlying.domain) code=\(underlying.code) — \(underlying.userInfo)")
            }
            return
        }

        // iMessage extension policy: don't interrupt the user with a sign-in sheet.
        // If they want to sign in, they can do so from the Settings app.
        if viewController != nil {
            print("⚠️ [GCAuth] GameKit offered a sign-in sheet — player is NOT signed in to Game Center on this device/sandbox. Skipping (no banner will show).")
            return
        }

        guard player.isAuthenticated else {
            print("⚠️ [GCAuth] callback had no error and no sheet, but isAuthenticated=false. No banner. (Often a sandbox Game Center account that isn't fully signed in.)")
            return
        }
        isAuthenticated = true

        Task { await loadAchievements() }
        flushPendingReports()
    }

    private func loadAchievements() async {
        do {
            let loaded = try await GKAchievement.loadAchievements()
            for achievement in loaded {
                // Don't clobber a locally-bumped value that hasn't been reported yet.
                if let existing = cachedAchievements[achievement.identifier],
                   existing.percentComplete >= achievement.percentComplete {
                    continue
                }
                cachedAchievements[achievement.identifier] = achievement
            }
        } catch {
            //print("Game Center: failed to load achievements: \(error.localizedDescription)")
        }
    }

    // MARK: - Reporting
    /// Mark an achievement as fully earned (100%).
    func report(_ achievement: Achievement) {
        report(achievement, percentComplete: 100)
    }

    /// Set the achievement's progress to a specific percentage (0–100). The value is clamped,
    /// and progress will never regress — if the cached value is already higher, this is a no-op.
    func report(_ achievement: Achievement, percentComplete: Double) {
        let id = achievement.rawValue
        let clamped = min(100, max(0, percentComplete))

        let gkAchievement = cachedAchievements[id] ?? GKAchievement(identifier: id)
        guard clamped > gkAchievement.percentComplete else { return }
        gkAchievement.percentComplete = clamped
        gkAchievement.showsCompletionBanner = true
        cachedAchievements[id] = gkAchievement

        guard isAuthenticated else {
            pendingReports[id] = gkAchievement
            return
        }
        sendReport([gkAchievement])
    }

    /// Add `delta` to the current cached progress for an achievement and report it.
    func increment(_ achievement: Achievement, by delta: Double) {
        let current = cachedAchievements[achievement.rawValue]?.percentComplete ?? 0
        report(achievement, percentComplete: current + delta)
    }

    /// Nonisolated convenience for reporting a single achievement from non–main-actor game logic. Hops to the main actor.
    nonisolated func report(achievement: Achievement) {
        Task { @MainActor in
            report(achievement)
        }
    }

    /// Call after recording a win in `WinTracker`. Marks the per-game first-win achievement as earned and updates the cumulative win milestones based on `WinTracker.totalWins`.
    /// Safe to call from any thread.
    nonisolated func reportWin(firstWin: Achievement) {
        Task { @MainActor in
            report(firstWin)
            let total = Double(WinTracker.shared.totalWins)
            report(.firstWinEver,     percentComplete: min(total * 100, 100))
            report(.twoWinsTotal,     percentComplete: min(total * 50,  100))
            report(.tenWinsTotal,     percentComplete: min(total * 10,  100))
            report(.twentyWinsTotal,  percentComplete: min(total * 5,   100))
            report(.hundredWinsTotal, percentComplete: min(total,       100))
        }
    }

    /// Reconciles Game Center achievements with the user's existing `WinTracker` counts so milestones earned before achievements were wired up (or before the player signed into Game Center) get unlocked on next launch.
    /// Reads win counts on a background thread; reports hop to the main actor and are queued by `report` until authentication completes. Safe to call from any thread.
    nonisolated func syncAchievementsWithWinCounts() {
        Task.detached(priority: .utility) {
            let ginWins     = WinTracker.shared.getWinCount(for: "Gin Rummy")
            let crazy8sWins = WinTracker.shared.getWinCount(for: "Crazy 8s")
            let golfWins    = WinTracker.shared.getWinCount(for: "Golf")
            let total = Double(ginWins + crazy8sWins + golfWins)

            await MainActor.run {
                if ginWins     > 0 { self.report(.firstWinGin) }
                if crazy8sWins > 0 { self.report(.firstWinCrazy8s) }
                if golfWins    > 0 { self.report(.firstWinGolf) }

                self.report(.firstWinEver,     percentComplete: min(total * 100, 100))
                self.report(.twoWinsTotal,     percentComplete: min(total * 50,  100))
                self.report(.tenWinsTotal,     percentComplete: min(total * 10,  100))
                self.report(.twentyWinsTotal,  percentComplete: min(total * 5,   100))
                self.report(.hundredWinsTotal, percentComplete: min(total,       100))
            }
        }
    }

    private func flushPendingReports() {
        guard !pendingReports.isEmpty else { return }
        let toReport = Array(pendingReports.values)
        pendingReports.removeAll()
        sendReport(toReport)
    }

    private func sendReport(_ achievements: [GKAchievement]) {
        Task {
            let ids = achievements.map { "\($0.identifier)=\(Int($0.percentComplete))%" }.joined(separator: ", ")
            do {
                try await GKAchievement.report(achievements)
                print("✅ [GameCenter] REPORT SUCCEEDED — \(ids)")
            } catch {
                let ns = error as NSError
                // code 15 == GKError.gameUnrecognized (the "no game matching descriptor" failure)
                print("❌ [GameCenter] REPORT FAILED (code \(ns.code)) — \(ids) — \(ns.localizedDescription)")
            }
        }
    }
}
