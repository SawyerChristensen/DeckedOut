//
//  CardView.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 1/2/26.
//

import SwiftUI

struct CardView: View { //where only one side is a (letter?)
    let frontImage: String
    var backLetter: String?
    var backImageName: String? = nil //custom card-back image; overrides the user's selected card back
    var cardHeight : CGFloat = 145
    var rotation: Double = 0 //default to face up

    @ObservedObject private var cardBackSelection = CardBackSelection.shared

    @ViewBuilder
    private var backImage: some View {
        if let letter = backLetter {
            LetterCardImage(character: letter)
        } else {
            Image(backImageName ?? cardBackSelection.selectedName)
                .resizable()
                .aspectRatio(0.7, contentMode: .fit)
        }
    }

    var body: some View {
        ZStack {
            // BACK VIEW
            backImage
                .frame(height: cardHeight)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
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
