//
//  TranscriptView.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 2/1/26.
//

import SwiftUI

struct TranscriptWaitingView: View {
    let gameState: GameState
    let isFromMe: Bool
    var onHeightChange: ((CGFloat) -> Void)? = nil
    
    private var playersHand: [Card] { isFromMe ? gameState.senderHand : gameState.receiverHand }
    private var opponentsHand: [Card] { isFromMe ? gameState.receiverHand : gameState.senderHand }
    private var playerWon: Bool { GinRummyValidator.canMeldAllCards(hand: playersHand) }
    private var opponentWon: Bool { GinRummyValidator.canMeldAllCards(hand: opponentsHand) }
    
    var body: some View {
        VStack {
            
            TranscriptPlayerHandView(cards: opponentWon ? opponentsHand : playersHand, playerWon: playerWon, opponentWon: opponentWon)
                .offset(y: opponentWon ? -30 : 50)
                .frame(height: 150)
                
            CaptionTextView(isWaiting: isFromMe, altText: opponentWon || playerWon ? "I won in Gin!" : "Your turn in Gin!")
            
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


struct CaptionTextView: View { //this is currently working fine, but not as originally designed. currently, multiline view does not actuall force multiple lines. what it does do is get rid of the mirroring in front of the text so that it is at least visually balanced in larger accessibility settings. it doesnt need to be changed, but multiline view triggers without actually forcing a multiline view
    let isWaiting: Bool
    let altText: String //if we are not waiting...
    @State private var dotCount = 0
    let timer = Timer.publish(every: 0.6, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Group {
            if isWaiting {
                ViewThatFits(in: .horizontal) {
                    singleLineView //try this first, if it doesnt...
                    
                    multiLineView //switch to this
                }
            } else {
                Text(altText)
            }
        }
        .font(.body)
        .fontWeight(.medium)
        .foregroundColor(.primary)
        .padding(.top, 6)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemBackground))
        .onReceive(timer) { _ in
            if isWaiting { dotCount = (dotCount + 1) % 4 }
        }
    }
        
    private var singleLineView: some View {
        (
            Text("...")
                .foregroundColor(.clear)
            + Text("Waiting for opponent")
            + Text(String(repeating: ".", count: dotCount))
            + Text(String(repeating: ".", count: 3 - dotCount))
                .foregroundColor(.clear)
        )
        .lineLimit(1)
    }
    
    private var multiLineView: some View { //note: not actually multi-line yet! basically just a "largeTextView" that balances the text better in higher text sizes
        (// (No Mirror Dots)
            Text("Waiting for opponent")
            + Text(String(repeating: ".", count: dotCount))
            // We still keep the right-hand buffer so the text doesn't
            // "jump" horizontally while animating on the last line.
            + Text(String(repeating: ".", count: 3 - dotCount))
                .foregroundColor(.clear)
        )
        .lineLimit(nil)
    }
}
