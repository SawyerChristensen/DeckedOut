//
//  TranscriptInviteView.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 2/6/26.
//

import SwiftUI

struct TranscriptInviteView: View {
    var onHeightChange: ((CGFloat) -> Void)? = nil

    var body: some View {
        VStack() {
            
            TranscriptInviteHandView()
                .offset(y: 33)
                .frame(height: 133)
                
            CaptionTextView(isWaiting: false, altText: "Let's Play Gin!") //technically the player IS waiting, but that bool is to display "waiting for opponent..." or not
            
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
