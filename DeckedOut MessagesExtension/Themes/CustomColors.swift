//
//  CustomColors.swift
//  DeckedOut MessagesExtension
//

import SwiftUI

// The app's custom palette, defined in code instead of the asset catalog.
//
// History: these colors once lived in Assets.xcassets/customColors and were used
// via `Color("name")`. While a now-removed `bundleIdentifier` swizzle was in place
// (it made the main bundle report the parent app's id so Game Center would
// recognize the game from inside the extension), named-color lookups broke —
// UIKit's named-asset resolution routes through the bundle identifier, so the
// rewritten id caused the lookup to miss the extension's compiled catalog and fall
// back to a default color. Moving the colors into code sidestepped bundle-based
// asset resolution entirely.
//
// The swizzle has since been removed (it could never make Game Center recognize
// the game — `gamed` validates the process by its code-signed App ID, not the
// rewritten string — and it broke asset resolution like this as a side effect).
// These colors are kept in code anyway: it's simpler and has no bundle dependency.
// Values mirror the original .colorset definitions exactly: sRGB, single
// appearance (the catalog's Dark slots were empty, so light and dark resolved to
// the same value).
//
// These live under `Palette` rather than as `Color` extensions because Xcode
// auto-generates `Color.salmonRed`-style symbols from the asset catalog, and a
// same-named extension would be ambiguous with those.
enum Palette {
    static let salmonRed = Color(.sRGB, red: 255 / 255, green:  75 / 255, blue:  75 / 255)
    static let lossRed   = Color(.sRGB, red: 255 / 255, green:  51 / 255, blue:  51 / 255)
    static let winYellow = Color(.sRGB, red: 255 / 255, green: 214 / 255, blue:   0 / 255)
    static let bookBrown = Color(.sRGB, red: 183 / 255, green: 138 / 255, blue: 102 / 255)
}
