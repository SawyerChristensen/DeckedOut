//
//  CardView.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 1/2/26.
//

import SwiftUI

struct CardView: View {
    let frontImage: String
    var backLetter: String?
    var cardHeight : CGFloat = 145
    var rotation: Double = 0 //default to face up
    
    private var backImageName: String {
        if let letter = backLetter { return "\(letter)Card" }
        else { return "cardBackRed" }
    }
        
    var body: some View {
        ZStack {
            // BACK VIEW
            Image(backImageName)
                .resizable()
                .aspectRatio(0.7, contentMode: .fit)
                .frame(height: cardHeight)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0)) //correcting the "mirroring" effect that distorts the image
                .modifier(FlipOpacity(rotation: rotation + 180))
            
            
            // FRONT VIEW
            Image(frontImage)
                .resizable()
                .aspectRatio(0.7, contentMode: .fit)
                .frame(height: cardHeight)
                .modifier(FlipOpacity(rotation: rotation))
        }
        .rotation3DEffect(
            .degrees(rotation),
            axis: (x: 0.0, y: 1.0, z: 0.0) // Rotate around Y-axis
        )
    }
}
