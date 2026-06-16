//
//  WaitingOverlayView.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 12/5/25.
//

import SwiftUI
import Combine

struct WaitingOverlayView: View {
    var joinedCount: Int? = nil
    var totalCount: Int? = nil
    var isSinglePlayer: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motionSpeed: Double { reduceMotion ? 0.66 : 1.0 } //animations should run at 2/3 speed when "Reduce Motion" is enabled
    @State private var isAnimating = false
    @State private var dotCount = 0

    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    private var waitingLabel: String { isSinglePlayer ? String(localized: "Waiting for opponent") : String(localized: "Waiting for opponents") }

    var body: some View {
        ZStack {
            // The Dimmed Background
            Color.black
                .opacity(0.3)
                .ignoresSafeArea()

            // The Animated Text
            VStack(spacing: 15) {
                ZStack(alignment: .leading) {
                    Text("\(waitingLabel)...").opacity(0) // Sizing placeholder
                    Text("\(waitingLabel)\(String(repeating: ".", count: dotCount))")
                }

                if let joined = joinedCount, let total = totalCount {
                    Text("Joined: \(joined) / \(total)")
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 25)
            .padding(.vertical, 15)
            .background(
                Rectangle()
                    .fill(Color(white: 0.15)) // basically 80% black
                    .shadow(radius: 10)
                    .cornerRadius(10)
                    .opacity(isAnimating ? 0.8 : 0.6)
            )
            .offset(y: -10)
        }
        // This ensures the user cannot tap cards underneath while waiting
        .contentShape(Rectangle()) //<- this doesnt seem to do anything though
        .onAppear {
            withAnimation( //for the opacity pulse
                .easeInOut(duration: 1)
                .repeatForever(autoreverses: true)
                .speed(motionSpeed)
            ) {
                isAnimating = true
            }
        }
        .onReceive(timer) { _ in
            // Cycle dotCount from 0 to 3
            dotCount = (dotCount + 1) % 4
        }
    }
}
