//
//  LetterCardView.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 2/23/26.
//

import SwiftUI

struct LetterCardImage: View {
    let character: String

    @ObservedObject private var cardBackSelection = CardBackSelection.shared
    let currentLanguage = Locale.preferredLanguages.first ?? "en"
    
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
        }
        return .custom("Holtzschue-Regular", fixedSize: 33) //originally size 30
    }
    
    private var useImageAsset: Bool {
        character == "!"
    }
    
    //private var isChinese: Bool {
    //    return currentLanguage.hasPrefix("zh-Hans") || currentLanguage.hasPrefix("zh-Hant")
    //}
    
    private var isHoltzschue: Bool {
        return font == .custom("Holtzschue-Regular", fixedSize: 33)
    }
    
    private var verticalCentering: CGFloat {
        if currentLanguage.hasPrefix("zh-Hans") {
            return -2
        } else if currentLanguage.hasPrefix("zh-Hant") {
            return 2
        } else { //then its Holtzschue
            return 3
        }
    }

    var body: some View {
        if useImageAsset {
            Image("\(character)Card")
                .resizable()
                .aspectRatio(0.7, contentMode: .fit)
        } else {
            Image(cardBackSelection.baseName)
                .resizable()
                .aspectRatio(0.7, contentMode: .fit)
                .overlay(
                    Text(character)
                        .font(font)
                        .offset(y: verticalCentering)
                        .foregroundStyle(.white)
                )
        }
    }
}

struct LetterCardView: View { //where both sides are letters
    let frontChar: String
    let backChar: String
    let isFlipped: Bool

    var rotation: Double {
        isFlipped ? 180 : 0
    }

    var body: some View {
        ZStack {
            // BACK (Visible when rotation is > 90)
            LetterCardImage(character: backChar)
                .modifier(FlipOpacity(rotation: rotation + 180))
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))

            // FRONT (Visible when rotation is < 90)
            LetterCardImage(character: frontChar)
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
