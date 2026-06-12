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
        // Game specific first wins
        case firstWinGin     = "deckedout.first_win.gin"
        case firstWinCrazy8s = "deckedout.first_win.crazy8s"
        case firstWinGolf    = "deckedout.first_win.golf"
        
        // Gin Rummy
        // implement: win by having your entire hand be 1 set (straight) of cards (achieveable more than once?)
        
        // Crazy 8s
        // implement: discard an 8 (hidden achievement) (8 points)
        // implement: discard a 2 (hidden achievement) (2 points)
        // implement: discard a queen (hidden achievement) (5 points)
        // implement: discard an ace (in group chat mode) (hidden achievement) (5 points)
        // implement: win in 8 turns exactly
        
        // Golf
        // implement: win by having 0 points ("Hole in one!") (hidden) (0 points) (achieveable more than once?)
        // implement: win using only royal cards in hand ("Wait... how?") (30 points)

        // Cumulative win milestones (progress-based, 0–100%)
        case firstWinEver     = "deckedout.wins.total.1"
        case twoWinsTotal     = "deckedout.wins.total.2"
        case tenWinsTotal     = "deckedout.wins.total.10"
        case twentyWinsTotal   = "deckedout.wins.total.20"
        case hundredWinsTotal = "deckedout.wins.total.100"
    }

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
        if error != nil {
            //print("Game Center authentication error: \(error?.localizedDescription ?? "")")
            return
        }
        // iMessage extension policy: don't interrupt the user with a sign-in sheet.
        // If they want to sign in, they can do so from the Settings app.
        if viewController != nil { return }

        guard GKLocalPlayer.local.isAuthenticated else { return }
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
            do {
                try await GKAchievement.report(achievements)
                    print("Reported: \(achievements.map { "\($0.identifier)=\($0.percentComplete)" })")
            } catch {
                print("Game Center: failed to report achievements: \(error.localizedDescription)")
            }
        }
    }
}
