//
//  CardView.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 1/2/26.
//

import SwiftUI

struct CardView: View {
    let imageName: String
    let isFaceUp: Bool
    var animatableFlipAngle: Double = 0
        
        var body: some View {
            let effectiveRotation = animatableFlipAngle + (isFaceUp ? 0 : 180)
            
            ZStack {
                // BACK VIEW
                Image("cardBackRed")
                    .resizable()
                    .aspectRatio(0.7, contentMode: .fit)
                    .frame(height: 145)
                    .shadow(radius: 3)
                    .modifier(FlipOpacity(rotation: effectiveRotation + 180))
                
                // FRONT VIEW
                Image(imageName)
                    .resizable()
                    .aspectRatio(0.7, contentMode: .fit)
                    .frame(height: 145)
                    .shadow(radius: 3)
                    .modifier(FlipOpacity(rotation: effectiveRotation))
            }
            .rotation3DEffect(
                .degrees(effectiveRotation),
                axis: (x: 0.0, y: 1.0, z: 0.0) // Rotate around Y-axis
            )
        }
    
    private func shouldShowFront(angle: Double) -> Bool {
        let normalized = angle.remainder(dividingBy: 360)
        return abs(normalized) < 90
    }
}
