//
//  LetterCardView.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 2/23/26.
//

import SwiftUI

struct LetterCardView: View {
    let frontChar: String
    let backChar: String
    let isFlipped: Bool
    
    var rotation: Double {
        isFlipped ? 180 : 0
    }
    
    var body: some View {
        ZStack {
            // BACK (Visible when rotation is > 90)
            Image("\(backChar)Card")
                .resizable()
                .aspectRatio(0.7, contentMode: .fit)
                .modifier(FlipOpacity(rotation: rotation + 180))
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0)) // Mirror correction
            
            // FRONT (Visible when rotation is < 90)
            Image("\(frontChar)Card")
                .resizable()
                .aspectRatio(0.7, contentMode: .fit)
                .modifier(FlipOpacity(rotation: rotation))
        }
        .rotation3DEffect(
            .degrees(isFlipped ? 180 : 0),
            axis: (x: 0.0, y: 1.0, z: 0.0)
        )
    }
}

struct FlipOpacity: AnimatableModifier {
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
