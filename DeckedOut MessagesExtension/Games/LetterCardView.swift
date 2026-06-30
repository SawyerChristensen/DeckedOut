//
//  LetterCardView.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 2/23/26.
//

import SwiftUI

struct LetterCardImage: View {
    let character: String
    var overrideCardBackName: String? = nil //if set, overrides the user's selected card back (e.g. show inviter's theme in transcripts)

    @ObservedObject private var cardBackSelection = CurrentTheme.shared
    private let currentLanguage = Locale.preferredLanguages.first ?? "en"

    // MARK: - Per-card-back styling
    /// Describes how a card back renders its letter: which font, how it's
    /// nudged vertically to look centered, and how wide its outline stroke is.
    private struct CardBackStyle {
        var fontName: String? = nil      // nil → default serif system font
        var fontSize: CGFloat = 30
        var verticalOffset: CGFloat = 0  // points to shift the letter for visual centering
        var strokeWidth: CGFloat = 0     // outline width in points; 0 = no stroke
    }

    private static let holtzschueFontName = "Holtzschue-Regular"

    /// Styling overrides keyed by card-back name. Any card back not listed here
    /// uses the default serif font with no offset and no stroke.
    private static let cardBackStyles: [String: CardBackStyle] = [
        // Card backs with a custom display font
        "cardBackWeb":       CardBackStyle(fontName: "KingthingsWidow", fontSize: 42, verticalOffset: 1),
        "cardBackKoi":       CardBackStyle(fontName: "SuperShake", fontSize: 26, verticalOffset: -2),
        "cardBackEnchanted": CardBackStyle(fontName: "BoecklinsUniverse", fontSize: 32, verticalOffset: 3),
        "cardBackRed":       CardBackStyle(fontName: holtzschueFontName, fontSize: 33, verticalOffset: 3),
        "cardBackBlue":      CardBackStyle(fontName: holtzschueFontName, fontSize: 33, verticalOffset: 3),
        "cardBackPurple":    CardBackStyle(fontName: holtzschueFontName, fontSize: 33, verticalOffset: 3),
        // Flag card backs: default serif font drawn with an outline stroke
        "cardBackAmerica":     CardBackStyle(verticalOffset: -2, strokeWidth: 2),
        "cardBackAustralia":   CardBackStyle(verticalOffset: -6, strokeWidth: 2),
        "cardBackAustria":     CardBackStyle(strokeWidth: 2),
        "cardBackCanada":      CardBackStyle(verticalOffset: 3),
        "cardBackDenmark":     CardBackStyle(verticalOffset: -15, strokeWidth: 2),
        "cardBackFinland":     CardBackStyle(verticalOffset: -19, strokeWidth: 2),
        "cardBackIndia":       CardBackStyle(strokeWidth: 2),
        "cardBackNorway":      CardBackStyle(verticalOffset: -17, strokeWidth: 2),
        "cardBackPoland":      CardBackStyle(strokeWidth: 2),
        "cardBackPortugal":    CardBackStyle(verticalOffset: 4),
        "cardBackSpain":       CardBackStyle(verticalOffset: 5, strokeWidth: 2),
        "cardBackSweden":      CardBackStyle(verticalOffset: -17, strokeWidth: 2),
        "cardBackSwitzerland": CardBackStyle(strokeWidth: 2),
        "cardBackTurkey":      CardBackStyle(verticalOffset: -13, strokeWidth: 2),
        "cardBackUK":          CardBackStyle(strokeWidth: 2),
        "cardBackVietnam":     CardBackStyle(strokeWidth: 2),
    ]

    /// The card-back style after applying language overrides. Chinese locales
    /// force their own font and vertical offset (but leave the stroke alone).
    private var style: CardBackStyle {
        var resolved = Self.cardBackStyles[effectiveName] ?? CardBackStyle()
        if currentLanguage.hasPrefix("zh-Hans") { // Simplified Chinese
            resolved.fontName = "baotuxiaobaiti"
            resolved.fontSize = 30
            resolved.verticalOffset = -2
        } else if currentLanguage.hasPrefix("zh-Hant") { // Traditional Chinese
            resolved.fontName = "GenRyuMinJP-Bold"
            resolved.fontSize = 30
            resolved.verticalOffset = 2
        }
        // Future per-language fonts (Hindi, Japanese, Korean, Russian) can be
        // layered in here the same way.
        return resolved
    }

    // MARK: - Derived appearance
    private var effectiveName: String { CurrentTheme.existingBackName(overrideCardBackName ?? cardBackSelection.selectedName) }

    private var effectiveBaseName: String {
        let candidate = effectiveName + "Base"
        return UIImage(named: candidate) != nil ? candidate : effectiveName
    }

    private var effectiveTextColor: Color {
        DeckTheme.theme(forLogoCard: effectiveName)?.textColor ?? Color(.white)
    }

    private var effectiveGlowColor: Color {
        let theme = DeckTheme.theme(forLogoCard: effectiveName)
        return theme?.outlineColor ?? theme?.textColor ?? Color(.white)
    }

    private var font: Font {
        if let name = style.fontName {
            return .custom(name, fixedSize: style.fontSize)
        }
        return .system(size: 30, weight: .bold, design: .serif)
    }

    /// The Holtzschue "!" has its own pre-rendered artwork. This is only true
    /// for the Holtzschue card backs (red/blue/purple) in non-Chinese locales,
    /// since Chinese overrides the font above.
    private var isHoltzschueExclamation: Bool {
        style.fontName == Self.holtzschueFontName && character == "!"
    }

    // MARK: - Body
    var body: some View {
        Image(effectiveBaseName)
            .resizable()
            .aspectRatio(0.7, contentMode: .fit)
            .overlay { letterOverlay }
    }

    @ViewBuilder
    private var letterOverlay: some View {
        if isHoltzschueExclamation {
            Image("\(character)Card")
                .resizable()
                .aspectRatio(0.7, contentMode: .fit)
        } else {
            ZStack {
                strokeOutline
                // Character on top of stroke
                Text(character)
                    .font(font)
                    .offset(y: style.verticalOffset)
                    .foregroundStyle(effectiveTextColor)
            }
        }
    }

    /// Fakes a text outline by drawing the character in the glow color eight
    /// times in a ring around the fill (SwiftUI Text has no native stroke).
    @ViewBuilder
    private var strokeOutline: some View {
        if style.strokeWidth > 0 {
            ForEach(0..<8, id: \.self) { i in
                let angle = Double(i) / 8 * 2 * .pi
                Text(character)
                    .font(font)
                    .foregroundStyle(effectiveGlowColor)
                    .offset(x: cos(angle) * style.strokeWidth,
                            y: sin(angle) * style.strokeWidth + style.verticalOffset)
            }
        }
    }
}

struct LetterCardView: View { //cards where both sides are letters
    let frontChar: String
    let backChar: String
    let isFlipped: Bool
    var cardBackName: String? = nil

    var rotation: Double {
        isFlipped ? 180 : 0
    }

    var body: some View {
        ZStack {
            // BACK (Visible when rotation is > 90)
            LetterCardImage(character: backChar, overrideCardBackName: cardBackName)
                .modifier(FlipOpacity(rotation: rotation + 180))
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))

            // FRONT (Visible when rotation is < 90)
            LetterCardImage(character: frontChar, overrideCardBackName: cardBackName)
                .modifier(FlipOpacity(rotation: rotation))
        }
        .rotation3DEffect(
            .degrees(isFlipped ? 180 : 0),
            axis: (x: 0.0, y: 1.0, z: 0.0)
        )
    }
}

struct FlipOpacity: AnimatableModifier { //also used in regular cardView
    var rotation: Double
    
    // This tells SwiftUI: "Interpolate this number, and rebuild the view every time it changes"
    var animatableData: Double {
        get { rotation }
        set { rotation = newValue }
    }
    
    func body(content: Content) -> some View {
        // Normalize angle to -180...180
        let normalized = rotation.remainder(dividingBy: 360)
        
        // Hard cutoff: If within 90 degrees of "center", it's visible.
        // Otherwise, instant 0 opacity.
        let isVisible = abs(normalized) < 90
        
        content
            .opacity(isVisible ? 1 : 0)
    }
}
