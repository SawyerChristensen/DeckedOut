//
//  MainBundleIdentifierOverride.swift
//  DeckedOut MessagesExtension
//
//

import Foundation
import ObjectiveC
import Darwin // dladdr / Dl_info, for caller inspection

/// Makes the **main bundle** report the parent app's identifier so Game Center
/// recognizes the game from inside the iMessage extension.
///
/// ## The problem
/// GameKit identifies "the game you're playing" by reading the running bundle's
/// `CFBundleIdentifier` (via `-[NSBundle bundleIdentifier]`) and matching it to a
/// Game Center–enabled App Store Connect record. Our GameKit code runs inside the
/// extension, whose bundle id is `Sawyer.DeckedOut.MessagesExtension`. There is no
/// App Store record for that id (extensions don't get their own listing — our
/// Game Center title, icon, and achievements all live under the parent app,
/// `Sawyer.DeckedOut`). So GameKit can't resolve a title: "Now Playing" shows up
/// blank with no icon, and achievement reports fail with
/// `GKError.gameUnrecognized` (code 15).
///
/// ## Why the override is UNCONDITIONAL
/// An earlier revision tried to narrow this to "rewrite the id *only* when a GameKit
/// frame is on the call stack" so asset-catalog lookups would keep seeing the real
/// id. That regressed Game Center: GameKit's authentication reads the bundle id from
/// paths whose in-process stack has **no** GameKit image on it (an XPC reply from the
/// `gamed` daemon, or a Foundation/CoreFoundation shim reading on GameKit's behalf).
/// On those reads the gate returned the real extension id, the server rejected it
/// (`gameUnrecognized`, code 15), and the sign-in banner never appeared. So we go back
/// to rewriting `Bundle.main.bundleIdentifier` for *every* reader. The asset-catalog
/// fallout (named `Color`/`Image` lookups missing) is handled separately by loading
/// those from an explicit bundle / from code.
///
/// ## How this fixes it
/// `bundleIdentifier` is an Objective-C method on `NSBundle`. The Objective-C
/// runtime lets us replace a method's *implementation* (its IMP) at runtime.
/// `install()` looks up the `Method` backing the getter, caches the original IMP so
/// it can still answer for non-main bundles, wraps a Swift closure as a new IMP with
/// `imp_implementationWithBlock`, and points the selector at it with
/// `method_setImplementation`.
///
/// ## Caveats
///  • Undocumented behavior. The `gamed` daemon can also validate the process by its
///    code-signed App ID, which code can't change. Re-test after major OS updates.
///  • Swizzling a system framework getter carries some App Store review risk.
///  • Call `install()` exactly once, before any GameKit API is touched.
///
/// ## Diagnostics
/// While `verboseLogging` is true, every main-bundle read is logged with a monotonic
/// timestamp, a sequence number, the value returned, and the caller's framework image
/// (so GameKit reads are visible against the noise). Filter the console for
/// `[BundleOverride]`. Flip `verboseLogging` to false once Game Center is confirmed.
enum MainBundleIdentifierOverride {

    /// The parent app's bundle identifier we want everyone (GameKit above all) to see.
    static let parentBundleIdentifier = "Sawyer.DeckedOut"

    /// Set to false to silence the per-read diagnostic logging.
    static var verboseLogging = true

    /// Guards against installing the swizzle more than once.
    private static var isInstalled = false

    /// Wall-clock moment install() ran, for relative timestamps. nil until installed.
    private static var installWallClock: Date?

    /// Count of main-bundle reads observed, for sequence numbers in the log.
    private static var readCount = 0

    /// Stop emitting per-read lines after this many, so heavy asset traffic can't
    /// flood the console into uselessness. The override itself keeps working past it.
    private static let maxLoggedReads = 400

    /// Replaces the implementation of `-[NSBundle bundleIdentifier]` so the main
    /// bundle reports `parentBundleIdentifier` to every reader. Idempotent.
    static func install() {
        guard !isInstalled else { return }
        isInstalled = true
        installWallClock = Date()

        // 1. Find the method backing the getter and remember its real implementation.
        let selector = #selector(getter: Bundle.bundleIdentifier)
        guard let method = class_getInstanceMethod(Bundle.self, selector) else {
            log("install() FAILED — could not find -[NSBundle bundleIdentifier]")
            return
        }
        let originalIMP = method_getImplementation(method)
        typealias OriginalFn = @convention(c) (AnyObject, Selector) -> NSString?

        let realID = unsafeBitCast(originalIMP, to: OriginalFn.self)(Bundle.main, selector) as String? ?? "nil"
        log("install() — real Bundle.main id = \(realID); will now report '\(parentBundleIdentifier)' to ALL readers")

        // 2. Build a replacement that rewrites the main bundle's id for everyone.
        //    The identity check (=== Bundle.main) avoids touching any other bundle and
        //    can't recurse, since `Bundle.main` is a different selector than this getter.
        let replacement: @convention(block) (AnyObject) -> NSString? = { bundle in
            if (bundle as? Bundle) === Bundle.main {
                logRead(returned: parentBundleIdentifier)
                return parentBundleIdentifier as NSString
            }
            let original = unsafeBitCast(originalIMP, to: OriginalFn.self)
            return original(bundle, selector)
        }

        // 3. Point the selector at our new implementation.
        method_setImplementation(method, imp_implementationWithBlock(replacement))
        log("install() COMPLETE — swizzle live")

        logIdentitySnapshot(context: "right after install")
    }

    /// Logs the bundle id as seen through every channel GameKit might use, so we can
    /// tell whether the swizzle actually covers the path that builds the server
    /// descriptor. The Objective-C getter is swizzled; the CoreFoundation C API and
    /// the raw Info.plist value are NOT — if those still show the extension id while
    /// NSBundle shows the parent, that mismatch is exactly what leaks to `gamed`.
    static func logIdentitySnapshot(context: String) {
        let ns = Bundle.main.bundleIdentifier ?? "nil"
        let cf = (CFBundleGetIdentifier(CFBundleGetMainBundle()) as String?) ?? "nil"
        let plist = (Bundle.main.infoDictionary?["CFBundleIdentifier"] as? String) ?? "nil"
        log("identity[\(context)] — NSBundle(swizzled)='\(ns)'  CFBundleGetIdentifier='\(cf)'  Info.plist='\(plist)'")
    }

    // MARK: - Diagnostics

    /// Logs a single main-bundle read: sequence number, monotonic timestamp, the value
    /// returned, and the caller framework (flagged when it's GameKit). Reads nothing
    /// from any Bundle, so it can't re-enter the swizzled getter.
    private static func logRead(returned: String) {
        readCount += 1
        guard verboseLogging, readCount <= maxLoggedReads else {
            if readCount == maxLoggedReads + 1 {
                log("…per-read logging capped at \(maxLoggedReads); override still active")
            }
            return
        }
        let caller = callerImage()
        let marker = caller.isGameKit ? "🎯 GAMEKIT" : "·"
        log("read #\(readCount) \(marker) caller=\(caller.name) -> '\(returned)'")
    }

    /// Identifies the nearest meaningful caller on the stack: the first GameKit-family
    /// frame if one is present anywhere, otherwise the first frame outside Foundation
    /// and this image. Also reports whether GameKit appears anywhere on the stack.
    private static func callerImage() -> (name: String, isGameKit: Bool) {
        var firstForeign: String?
        for address in Thread.callStackReturnAddresses {
            guard let raw = UnsafeRawPointer(bitPattern: address.uintValue) else { continue }
            var info = Dl_info()
            guard dladdr(raw, &info) != 0, let cName = info.dli_fname else { continue }
            let path = String(cString: cName)
            let image = (path as NSString).lastPathComponent

            if path.contains("GameKit") || path.contains("GameCenter") || path.contains("gamed") {
                return (image, true)
            }
            // Remember the first frame that isn't Foundation or our own override code,
            // as a best-effort "who asked" when GameKit isn't involved.
            if firstForeign == nil,
               !path.contains("Foundation"),
               !path.contains("MessagesExtension") {
                firstForeign = image
            }
        }
        return (firstForeign ?? "unknown", false)
    }

    /// Emits a timestamped diagnostic line. Timestamp is seconds since install (monotonic
    /// within a launch); falls back to a wall-clock note before install completes.
    private static func log(_ message: String) {
        guard verboseLogging else { return }
        let stamp: String
        if let start = installWallClock {
            stamp = String(format: "+%.3fs", Date().timeIntervalSince(start))
        } else {
            stamp = "+0.000s"
        }
        print("[BundleOverride] \(stamp) \(message)")
    }
}
