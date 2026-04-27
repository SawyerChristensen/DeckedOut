//
//  WinScreenView.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 12/5/25.
//

import SwiftUI
import StoreKit

struct WinScreenView: View {
    //var onRestart: () -> Void
    let playerHasWon: Bool
    let winMessage: String
    
    @Environment(\.requestReview) private var requestReview
    @State private var animateIn = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 25) {
                Image(systemName: "trophy.fill") //or "xmark" for loss, but it should be bolder
                    .font(.system(size: 80))
                    .foregroundStyle(playerHasWon ? LinearGradient(colors: [
                        Color(red: 1.0, green: 1.0, blue: 0.6),
                        Color(red: 1.0, green: 0.8, blue: 0.33)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                    ) : LinearGradient(colors: [
                        Color(red: 1.0, green: 0.0, blue: 0.0),
                        Color(red: 1.0, green: 0.0, blue: 0.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                    ))
                    .shadow(color: playerHasWon ? .yellow : .red, radius: 10)
                    .scaleEffect(animateIn ? 1.0 : 0.5)
                
                VStack(spacing: 8) {
                    Text(winMessage)
                        .font(.system(size: 36, weight: .black))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    if playerHasWon {
                        Text("You won!")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.9))
                    } else {
                        Text("Your opponent won!")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                
                /*Button(action: onRestart) {
                    Text("Play Again")
                        .font(.title3.bold())
                        .foregroundColor(.blue)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 40)
                        .background(Capsule().fill(Color.white))
                        .shadow(radius: 5)
                }*/
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(.ultraThinMaterial) // glassmorphism effect
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .scaleEffect(animateIn ? 1.0 : 0.8)
            .opacity(animateIn ? 1.0 : 0.0)
        }
        .onAppear {
            withAnimation(.spring(response: 1, dampingFraction: 0.7)) {
                animateIn = true
            }
            if playerHasWon && WinTracker.shared.totalWins >= 3 {
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    await MainActor.run { requestReview() }
                }
            }
        }
    }
}
