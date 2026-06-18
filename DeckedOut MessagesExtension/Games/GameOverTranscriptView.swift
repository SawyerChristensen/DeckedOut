//
//  GameOverTranscriptView.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 4/25/26.
//

import SwiftUI

struct GameOverTranscriptView: View {
    let playerWon: Bool

    var body: some View {
        if playerWon {
            TimelineView(.animation) { timeline in
                let angle = timeline.date.timeIntervalSinceReferenceDate * (2 * .pi / 3)

                Image(systemName: "trophy.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(LinearGradient(colors: [
                        Color(red: 1.0, green: 1.0, blue: 0.6),
                        Color(red: 1.0, green: 0.8, blue: 0.33)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                    ))
                    .shadow(color: Palette.winYellow, radius: 5,
                            x: 4 * sin(angle),
                            y: -4 * cos(angle))
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 6)
                    .padding(.top, 10)
                    .frame(height: 150)
            }
        } else {
            Image(systemName: "xmark")
                .font(.system(size: 90))
                .fontWeight(.semibold)
                .foregroundStyle(LinearGradient(colors: [
                    Color(red: 1.0, green: 0.4, blue: 0.4),
                    Color(red: 1.0, green: 0.0, blue: 0.0)
                ],
                startPoint: .top,
                endPoint: .bottom
                ))
                .shadow(color: Palette.lossRed, radius: 10)
                .shadow(color: .black.opacity(0.15), radius: 2, y: 6)
                .padding(.top, 10)
                .frame(height: 150)
        }
    }
}
