//
//  JoinGameView.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 5/10/26.
//

import SwiftUI

struct JoinGameView: View {
    let game: any GroupChatCapable
    let needsToJoin: Bool
    let currentPlayers: Int
    let maxPlayers: Int
    
    @State private var isJoining = false
    
    var body: some View {
        VStack(spacing: 30) {

            if !isJoining {
                if game.joinWasOverwritten {
                    Text("Another player joined at the same time you did. Please try again.")
                        .font(.system(.headline, design: .monospaced, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                
                JoinGameButton(game: game, isJoining: $isJoining)
                
                //Divider()
                
            } else { //possibly re-add settling after join to prevent showing wrong hand if our join was overwritten
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
                Text("Joining…")
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text("\(currentPlayers) / \(maxPlayers)")
                .font(.system(.largeTitle, design: .serif, weight: .bold))
                .foregroundStyle(.white)

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FeltBackgroundView())
        .onChange(of: needsToJoin) { _, newValue in
            if newValue { isJoining = false }
        }
    }
}

struct JoinGameButton: View {
    let game: any GroupChatCapable
    @Binding var isJoining: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motionSpeed: Double { reduceMotion ? 0.66 : 1.0 } //animations should run at 2/3 speed when "Reduce Motion" is enabled
    @State private var isPulsating = false

    var body: some View {
        Button {
            isJoining = true
            game.joinGame(shouldBroadcast: true)
        } label: {
            Text("Join Game")
                .font(.system(.largeTitle, design: .serif, weight: .bold))
                .foregroundStyle(.white)
                .scaleEffect(isPulsating ? 1.05 : 1)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true).speed(motionSpeed)) {
                        isPulsating = true
                    }
                }
                .onDisappear {
                    isPulsating = false
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.black.opacity(0.3))
                            .offset(y: 4)
                        RoundedRectangle(cornerRadius: 15)
                            .fill(LinearGradient(colors: [Color(white: 0.3), Color(white: 0.1)], startPoint: .top, endPoint: .bottom))
                    }
                )
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.2), lineWidth: 2))
                .shadow(color: .black.opacity(0.2), radius: 5, x: 5, y: 5)
        }
        .buttonStyle(.plain)
    }
}
