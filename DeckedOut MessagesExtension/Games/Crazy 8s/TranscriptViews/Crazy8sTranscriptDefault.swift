//
//  Crazy8sTranscriptDefault.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 2/23/26.
//

import SwiftUI

struct Crazy8sTranscriptDefault: View {
    let gameState: Crazy8sGameState
    let isFromMe: Bool
    var onHeightChange: ((CGFloat) -> Void)? = nil
    
    private var playersHand: [Card] { isFromMe ? gameState.senderHand : gameState.receiverHand }
    private var opponentsHand: [Card] { isFromMe ? gameState.receiverHand : gameState.senderHand }
    private var playerWon: Bool { playersHand.count == 0 }
    private var opponentWon: Bool { opponentsHand.count == 0 }
    
    var body: some View {
        VStack {

            if playerWon {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(LinearGradient(colors: [
                        Color(red: 1.0, green: 1.0, blue: 0.6), // Bright Yellow at the top
                        Color(red: 1.0, green: 0.8, blue: 0.33) // Orangish gold at the bottom
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                    ))
                    .shadow(color: .yellow, radius: 5, y: -4)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 6)
                    .padding(.top, 10)
                    .frame(height: 150)
            } else if opponentWon {
                Image(systemName: "xmark")
                    .font(.system(size: 90))
                    .fontWeight(.semibold)
                    .foregroundStyle(LinearGradient(colors: [
                        Color(red: 1.0, green: 0.4, blue: 0.4), // Bright red at the top
                        Color(red: 1.0, green: 0.0, blue: 0.0)  // Solid red at the bottom
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                    ))
                    .shadow(color: .red, radius: 10)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 6)
                    .padding(.top, 10)
                    .frame(height: 150)
            } else {
                Crazy8sTranscriptPlayerHand(cards: playersHand, playerWon: playerWon, opponentWon: opponentWon)
                    .offset(y: opponentWon ? -30 : 50)
                    .frame(height: 150)
            }
                
            CaptionTextView(isWaiting: isFromMe, altText: opponentWon || playerWon ? "I won in Crazy 8s!" : "Your turn in Crazy 8s!")
            
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
