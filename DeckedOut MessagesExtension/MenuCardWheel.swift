//
//  MenuCardWheel.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 2/17/26.
//

import SwiftUI

struct CardWheelMenu: View {
    let games: [MenuGame]
    @Binding var selectedIndex: Int
    var onActiveIndexChange: (Int) -> Void
    var onSelect: (Int) -> Void
    
    init(games: [MenuGame], selectedIndex: Binding<Int>, onActiveIndexChange: @escaping (Int) -> Void, onSelect: @escaping (Int) -> Void) {
        self.games = games
        self._selectedIndex = selectedIndex
        self.onActiveIndexChange = onActiveIndexChange
        self.onSelect = onSelect
    }
    
    private var cardWidth: CGFloat = 140
    private var cardHeight: CGFloat = 200
    private let spacing: CGFloat = -80
    private let fanningAngle: Double = 12
    
    @State private var isDragging = false
    @GestureState private var dragTranslation: CGFloat = 0 //to track the drag amount while it's happening.
    private var stepWidth: CGFloat {
        cardWidth + spacing
    }
    private var continuousIndex: Double { // Calculate a fluid index that changes mid-swipe
        Double(selectedIndex) - (Double(dragTranslation) / stepWidth)
    }
    
    private var activeIndex: Int {
        let index = Int(round(continuousIndex))
        return max(0, min(games.count - 1, index))
    }
    
    private var currentXOffset: CGFloat {
        let middleIndex = Double(games.count - 1) / 2.0
        // Base position based on the selection, plus the live drag movement
        let baseOffset = (middleIndex - Double(selectedIndex)) * stepWidth
        return baseOffset + dragTranslation
    }
    
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(Array(games.enumerated()), id: \.element.id) { index, game in
                
                let distance = Double(index) - continuousIndex // Calculate distance using the continuous floating-point index
                // If distance is between -0.5 and 0.5, it's the primary card right now
                let isCenter = abs(distance) < 0.5
                let yOffset = abs(distance * 15)
                
                CardView(frontImage: game.logoCard, cardHeight: cardHeight, rotation: isCenter ? 0 : -180)
                    .zIndex(Double(games.count) - abs(distance))
                    .rotationEffect(.degrees(distance * fanningAngle))
                    .offset(y: yOffset)
                    .onTapGesture {
                        onSelect(index)
                    }
            }
            .frame(width: cardWidth, height: cardHeight)
        }
        .offset(x: currentXOffset)
        .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.8), value: dragTranslation)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedIndex)
        .onChange(of: activeIndex) { _, newValue in
            if isDragging {
                onActiveIndexChange(newValue)
            }
        }
        .gesture(
            DragGesture()
                .updating($dragTranslation) { value, state, _ in // Update the translation while the drag is active
                    if !isDragging { isDragging = true }
                    state = value.translation.width
                }
                .onEnded { value in  // Predict where the scroll should land based on gesture speed and distance
                    isDragging = false
                    let predictedDrag = value.predictedEndTranslation.width
                    let indexShift = Int(round(-predictedDrag / stepWidth))
                    
                    let newIndex = max(0, min(games.count - 1, selectedIndex + indexShift))
                    
                    if newIndex != selectedIndex {
                        onSelect(newIndex)
                    }
                }
        )
    }
}
