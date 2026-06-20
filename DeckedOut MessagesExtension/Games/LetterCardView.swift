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

    @ObservedObject private var cardBackSelection = DeckThemeSelection.shared
    let currentLanguage = Locale.preferredLanguages.first ?? "en"

    private var effectiveName: String { DeckThemeSelection.existingBackName(overrideCardBackName ?? cardBackSelection.selectedName) }
    private var effectiveBaseName: String {
        let candidate = effectiveName + "Base"
        return UIImage(named: candidate) != nil ? candidate : effectiveName
    }
    private var effectiveTextColor: Color {
        return DeckTheme.theme(forLogoCard: effectiveName)?.secondaryColor ?? Color(.white)
    }

    private var font: Font {
        if currentLanguage.hasPrefix("zh-Hans") { // Simplified Chinese
            return .custom("baotuxiaobaiti", fixedSize: 30)
        } else if currentLanguage.hasPrefix("zh-Hant") { // Traditional Chinese
            return .custom("GenRyuMinJP-Bold", fixedSize: 30)
        //} else if currentLanguage.hasPrefix("hi") { // Hindi
            //return .system(size: 30, weight: .regular, design: .serif)
        //} else if currentLanguage.hasPrefix("ja") { // Japanese
            //return .custom("GenRyuMinJP-Bold", size: 30)
        //} else if currentLanguage.hasPrefix("ko") { // Korean
            //return .custom("AppleSDGothicNeo-SemiBold", size: 28)
            //return .system(size: 30, weight: .regular, design: .serif)
        //} else if currentLanguage.hasPrefix("ru") { // Russian
            //return .system(size: 30, weight: .regular, design: .serif)
        } else if effectiveName == "cardBackWeb" {
            return .custom("KingthingsWidow", fixedSize: 42)
        } else if effectiveName == "cardBackKoi" {
            return .custom("SuperShake", fixedSize: 26)
        } else if effectiveName == "cardBackEnchanted" {
            return .custom("BoecklinsUniverse", fixedSize: 32)
        }
        return .custom("Holtzschue-Regular", fixedSize: 33) //originally size 30
    }
    
    private var isHoltzschue: Bool {
        return font == .custom("Holtzschue-Regular", fixedSize: 33)
    }

    private var isExclamation: Bool {
        isHoltzschue && character == "!"
    }
    
    private var verticalCentering: CGFloat {
        if currentLanguage.hasPrefix("zh-Hans") {
            return -2
        } else if currentLanguage.hasPrefix("zh-Hant") {
            return 2
        } else if isHoltzschue {
            return 3
        } else if effectiveName == "cardBackWeb" {
            return 1
        } else if effectiveName == "cardBackKoi" {
            return -2
        } else if effectiveName == "cardBackEnchanted" {
            return 3
        } else {
            return 0
        }
    }

    var body: some View {
        Image(effectiveBaseName)
            .resizable()
            .aspectRatio(0.7, contentMode: .fit)
            .overlay {
                if isExclamation {
                    Image("\(character)Card")
                        .resizable()
                        .aspectRatio(0.7, contentMode: .fit)
                } else {
                    Text(character)
                        .font(font)
                        .offset(y: verticalCentering)
                        .foregroundStyle(effectiveTextColor)
                }
            }
    }
}

struct LetterCardView: View { //where both sides are letters
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
