//
//  WaitingOverlayView.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 12/5/25.
//

import SwiftUI

struct WaitingOverlayView: View {
    @State private var isAnimating = false
    @State private var dotCount = 0
    
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // The Dimmed Background
            Color.black
                .opacity(0.3)
                .ignoresSafeArea()
            
            // The Animated Text
            VStack(spacing: 15) {
                ZStack(alignment: .leading) {
                    Text("Waiting for opponent...") // Invisible placeholder for sizing
                        .opacity(0)
                    
                    Text("Waiting for opponent\(String(repeating: ".", count: dotCount))")
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
                //.scaleEffect(isAnimating ? 1.05 : 1.0) // Pulse size
            }
        }
        // This ensures the user cannot tap cards underneath while waiting
        .contentShape(Rectangle()) //<- this doesnt seem to do anything though
        .onAppear {
            withAnimation( //for the opacity pulse
                .easeInOut(duration: 1)
                .repeatForever(autoreverses: true)
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
