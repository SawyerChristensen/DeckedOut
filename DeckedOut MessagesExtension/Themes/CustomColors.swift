//
//  CustomColors.swift
//  DeckedOut MessagesExtension
//

import SwiftUI

// The app's custom palette, defined in code instead of the asset catalog.
//
// These colors previously lived in Assets.xcassets/customColors and were used
// via `Color("name")`. That initializer resolves the name against `Bundle.main`,
// and UIKit locates a bundle's compiled asset catalog by the bundle's
// *identifier*. `MainBundleIdentifierOverride` deliberately makes the main
// bundle report the parent app's identifier (so Game Center recognizes the game
// from inside the extension), which causes the named-color lookup to miss the
// extension's catalog and fall back to a default color.
//
// Defining the colors in code sidesteps bundle-based asset resolution entirely,
// so they're immune to the identifier override. Values mirror the original
// .colorset definitions exactly: sRGB, single appearance (the catalog's Dark
// slots were empty, so light and dark resolved to the same value).
//
// These live under `Palette` rather than as `Color` extensions because Xcode
// auto-generates `Color.salmonRed`-style symbols from the asset catalog; a
// same-named extension would be ambiguous with those (and the generated ones
// resolve through the bundle, so they break under the override too).
enum Palette {
    static let salmonRed = Color(.sRGB, red: 255 / 255, green:  75 / 255, blue:  75 / 255)
    static let lossRed   = Color(.sRGB, red: 255 / 255, green:  51 / 255, blue:  51 / 255)
    static let winYellow = Color(.sRGB, red: 255 / 255, green: 214 / 255, blue:   0 / 255)
    static let bookBrown = Color(.sRGB, red: 183 / 255, green: 138 / 255, blue: 102 / 255)
}
