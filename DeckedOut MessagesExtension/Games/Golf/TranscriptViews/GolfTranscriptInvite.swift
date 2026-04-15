//
//  GolfTranscriptInvite.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 4/15/26.
//

import SwiftUI

struct GolfTranscriptInvite: View {
    var onHeightChange: ((CGFloat) -> Void)? = nil

    var body: some View {
        VStack() {
            
            GolfTranscriptInviteHand()
                .offset(y: 40)
                .frame(height: 150)
                
            CaptionTextView(isWaiting: false, altText: "Let's Play Golf!") //technically the player IS waiting, but that bool is to display "waiting for opponent..." or not
            
        }
        .background( //for measuring & reporting the view height
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        onHeightChange?(geometry.size.height)
                    }
                    .onChange(of: geometry.size.height) { _, newHeight in
                        onHeightChange?(newHeight)
                    }
            }
        )
        .background(Image("feltBackgroundLight")
            .resizable()
            .aspectRatio(contentMode: .fill)
        )
    }
}
