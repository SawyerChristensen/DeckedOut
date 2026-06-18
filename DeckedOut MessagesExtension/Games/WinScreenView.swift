//
//  WinScreenView.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 12/5/25.
//

import SwiftUI
import StoreKit

struct WinScreenView: View {
    let playerHasWon: Bool
    let winMessage: String

    @Environment(\.requestReview) private var requestReview
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motionSpeed: Double { reduceMotion ? 0.66 : 1.0 } //animations should run at 2/3 speed when "Reduce Motion" is enabled
    @State private var animateIn = false
    @State private var dismissed = false

    var body: some View {
        if !dismissed {
            ZStack {
                Color.black.opacity(animateIn ? 0.3 : 0.0)
                    .ignoresSafeArea()
                    .onTapGesture { dismiss() }

                VStack(spacing: 25) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(playerHasWon ? LinearGradient(colors: [ //the golden win color scheme
                            Color(red: 1.0, green: 1.0, blue: 0.6),
                            Color(red: 1.0, green: 0.8, blue: 0.33)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                        ) : LinearGradient(colors: [ //the red loss color scheme
                            Color(red: 1.0, green: 0.4, blue: 0.4),
                            Color(red: 1.0, green: 0.0, blue: 0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                        ))
                        .shadow(color: playerHasWon ? Palette.winYellow : Palette.lossRed, radius: 10)
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
                }
                .padding(40)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                //.onTapGesture { dismiss() }
                .scaleEffect(animateIn ? 1.0 : 0.8)
                .opacity(animateIn ? 1.0 : 0.0)
            }
            .onAppear {
                withAnimation(.spring(response: 1, dampingFraction: 0.7).speed(motionSpeed)) {
                    animateIn = true
                }
                if playerHasWon && WinTracker.shared.totalWins >= 2 {
                    Task {
                        try? await Task.sleep(for: .seconds(1))
                        await MainActor.run { requestReview() }
                    }
                }
            }
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.3).speed(motionSpeed)) {
            dismissed = true
        }
    }
}
