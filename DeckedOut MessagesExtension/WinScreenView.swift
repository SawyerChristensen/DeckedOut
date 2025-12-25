//
//  WaitingOverlayView.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 12/5/25.
//

import SwiftUI

struct WinScreenView: View {
    //var onRestart: () -> Void
    @EnvironmentObject var game: GameManager
    @State private var animateIn = false
    
    var body: some View {
        ZStack {

            VStack(spacing: 25) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 80))
                    .foregroundColor(game.playerHasWon ? .yellow : .red)
                    .shadow(color: .orange, radius: 10)
                    .scaleEffect(animateIn ? 1.0 : 0.5)
                
                VStack(spacing: 8) {
                    Text("GIN RUMMY!")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    
                    if game.playerHasWon {
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
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                animateIn = true
            }
        }
    }
}
