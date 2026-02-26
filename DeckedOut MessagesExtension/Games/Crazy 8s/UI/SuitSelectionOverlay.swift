//
//  SuitSelectionOverlay.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 2/24/26.
//

import SwiftUI

struct SuitSelectionOverlay: View {
    @EnvironmentObject var game: Crazy8sManager
    let suits = Suit.allCases
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3) //dims the entire screen
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Text("Choose a Suit")
                    .font(.system(.title2))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 2, y: 2)
                
                HStack(spacing: 12) {
                    ForEach(suits, id: \.self) { suit in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                game.submitChosenSuit(suit)
                            }
                        }) {
                            Image(systemName: suit.sfSymbolName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 36, height: 36)
                                .symbolRenderingMode(.multicolor)
                                .padding(12)
                                .background( //Symbol button glass background
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(.thinMaterial)
                                )
                                .overlay( //Symbol button edge highlight
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(
                                            LinearGradient(
                                                colors: [.white.opacity(0.6), .white.opacity(0.1)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(GlassButtonStyle()) ///custom tactile scale effect (defined below)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
            .background( //the glass background
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay( //the edge highlight
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.5), .white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: .black.opacity(0.25), radius: 30, x: 5, y: 15)
            .offset(y: -200)
        }
    }
}

// MARK: - Custom Button Style for Tactility
struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0) /// Scale down slightly when pressed
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
