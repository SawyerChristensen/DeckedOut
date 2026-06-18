//
//  MainBundleIdentifierOverride.swift
//  DeckedOut MessagesExtension
//
//

import Foundation
import ObjectiveC

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
/// ## How this fixes it
/// `bundleIdentifier` is an Objective-C method on `NSBundle`. The Objective-C
/// runtime lets us replace a method's *implementation* (its IMP — the actual
/// function pointer the selector dispatches to) at runtime. `install()` does
/// exactly that, in three steps:
///
///  1. **Look up the method.** `class_getInstanceMethod` returns the `Method`
///     backing the `bundleIdentifier` getter on `NSBundle`, and we cache its
///     current implementation pointer (`originalIMP`) so we can still call it.
///  2. **Build a replacement.** `imp_implementationWithBlock` wraps a Swift
///     closure in an IMP-compatible trampoline. Our closure receives the
///     `NSBundle` the getter was called on and decides what to return.
///  3. **Install it.** `method_setImplementation` points the selector at our new
///     IMP. From now on, *every* `someBundle.bundleIdentifier` call routes
///     through our closure instead of Foundation's original.
///
/// The closure is deliberately narrow: it only rewrites the result when the
/// receiver is `Bundle.main` (identity-compared, so it can't recurse or misfire),
/// returning `parentBundleIdentifier`. For any other bundle it calls the cached
/// `originalIMP` and returns Foundation's real answer. So the parent id is the
/// *only* observable change, and only for the one process-wide main bundle.
///
/// ## Why it's safe for the rest of the app
/// This rewrites a single string getter — not the app's actual identity. The
/// code-signed App ID, sandbox container, keychain/app-group entitlements, and
/// Messages-framework registration are all keyed off the real signed identifier
/// (or the low-level CoreFoundation `CFBundleGetIdentifier` C API, which this
/// doesn't touch), so storage, IAP, and message sending are unaffected. The only
/// consumer that reads the swizzled getter and matters to us is GameKit.
///
/// ## Caveats
///  • Undocumented behavior. GameKit reads the bundle id client-side, but the
///    `gamed` daemon can also validate the process by its code-signed App ID
///    (`TEAM.Sawyer.DeckedOut.MessagesExtension`), which code can't change. On OS
///    versions that cross-check the two this would still fail with
///    `gameUnrecognized` — confirmed working on current iOS, re-test after major
///    OS updates.
///  • Swizzling a system framework getter carries some App Store review risk.
///  • The change is process-global and permanent once installed, and it flips the
///    return value mid-launch (real id before `install()`, parent id after).
///    Nothing else in this target reads `Bundle.main.bundleIdentifier`, so treat
///    that getter as unreliable here and don't start depending on it.
///  • Call `install()` exactly once, before any GameKit API is touched.
enum MainBundleIdentifierOverride {

    /// The parent app's bundle identifier we want GameKit to see.
    static let parentBundleIdentifier = "Sawyer.DeckedOut"

    /// Guards against installing the swizzle more than once.
    private static var isInstalled = false

    /// Replaces the implementation of `-[NSBundle bundleIdentifier]` so the main
    /// bundle reports `parentBundleIdentifier`. Idempotent; safe to call repeatedly.
    static func install() {
        guard !isInstalled else { return }
        isInstalled = true

        // 1. Find the method backing the getter and remember its real implementation.
        let selector = #selector(getter: Bundle.bundleIdentifier)
        guard let method = class_getInstanceMethod(Bundle.self, selector) else { return }
        let originalIMP = method_getImplementation(method)
        typealias OriginalFn = @convention(c) (AnyObject, Selector) -> NSString?

        // 2. Build a replacement that only rewrites the main bundle. The identity
        //    check (=== Bundle.main) avoids touching any other bundle and can't
        //    recurse, since `Bundle.main` is a different selector than this getter.
        let replacement: @convention(block) (AnyObject) -> NSString? = { bundle in
            if (bundle as? Bundle) === Bundle.main {
                return parentBundleIdentifier as NSString
            }
            let original = unsafeBitCast(originalIMP, to: OriginalFn.self)
            return original(bundle, selector)
        }

        // 3. Point the selector at our new implementation.
        method_setImplementation(method, imp_implementationWithBlock(replacement))
    }
}
