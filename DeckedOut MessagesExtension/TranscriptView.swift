//
//  TranscriptView.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 2/1/26.
//

import SwiftUI
//import Messages

struct TranscriptView: View {
    let gameState: GameState
    let isFromMe: Bool
    
    static let viewHeight: CGFloat = 200

    private var cards: [Card] {
        isFromMe ? gameState.senderHand : gameState.receiverHand
    }

    var body: some View {
        
        ZStack(alignment: .bottom) {
            // The Game Preview
            VStack(spacing: -40) {
                // Deck & Discard
                HStack(spacing: 0) {
                    Spacer()
                    deckStack
                    Spacer()
                    discardStack
                    Spacer()
                }
                .offset(y: -69)
                .opacity(0) //for now...
                
                TranscriptHandView(cards: cards)
                    .offset(y: -25)
            }
            
            // The Caption Bar
            ZStack(alignment: .top) {
                Color(UIColor.secondarySystemBackground)
                    .frame(height: 50)
                
                Text(isFromMe ? "Waiting for opponent..." : "Your turn!")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .padding(.top, 7)
            }
            //.padding(.bottom)
            
        }
        .frame(height: TranscriptView.viewHeight)
        .background(Image("feltBackgroundLight")
            .resizable()
            .aspectRatio(contentMode: .fill)
        )
    }
    
    private var deckStack: some View {
        ZStack {
            ForEach(0..<5) { i in
                Image("cardBackRed")
                    .resizable()
                    .aspectRatio(0.7, contentMode: .fit)
                    .frame(height: 145)
                    .offset(x: CGFloat(-i) * 3, y: CGFloat(-i) * 3)
                    .shadow(radius: i == 4 ? 1 : 8)
            }
        }
    }

    private var discardStack: some View {
        Group {
            if let topDiscard = gameState.discardPile.last {
                CardView(frontImage: topDiscard.imageName)
                    .frame(height: 145) // Matches the deck height
                    .shadow(color: .black.opacity(0.2), radius: 5)
            }
        }
    }
}

/*
struct CaptionTextView: View { //for animating "waiting for opponent..." but that may be too much motion
    let isWaiting: Bool
    @State private var dotCount = 0
    let timer = Timer.publish(every: 0.6, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Text(isWaiting ? "Waiting for opponent\(String(repeating: ".", count: dotCount))" : "Your turn!")
            .font(.body)
            .fontWeight(.medium)
            .foregroundColor(.primary)
            .monospacedDigit()
            .frame(width: 220, alignment: .leading)
            .onReceive(timer) { _ in
                if isWaiting {
                    dotCount = (dotCount + 1) % 4
                }
            }
    }
}*/
