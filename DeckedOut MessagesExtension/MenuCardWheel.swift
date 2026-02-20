//
//  MenuCardWheel.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 2/17/26.
//

import SwiftUI

struct MenuCardWheel: View {
    let games: [MenuGame]
    var onActiveIndexChange: (Int) -> Void
    var userSelectedGame: (Int) -> Void
    @Binding var hasSelectedGame: Bool //should get triggered at the same time userSelectedGame is called
    
    init(games: [MenuGame], onActiveIndexChange: @escaping (Int) -> Void, userSelectedGame: @escaping (Int) -> Void, hasSelectedGame: Binding<Bool>) {
        self.games = games
        self.onActiveIndexChange = onActiveIndexChange
        self.userSelectedGame = userSelectedGame
        self._hasSelectedGame = hasSelectedGame
    }
    
    private var cardWidth: CGFloat { hasSelectedGame ? 175 : 140 }
    private var cardHeight: CGFloat { hasSelectedGame ? 250 : 200 }
    private var spacing: CGFloat { hasSelectedGame ? -30 : -80 }
    private var fanningAngle: Double { hasSelectedGame ? 16 : 12 }
    
    @State private var currentCenterIndex: Int = 0 //the default game that is shown when opening the main menu
    @State private var isDragging = false
    @GestureState private var dragTranslation: CGFloat = 0 //to track the drag amount while it's happening.
    
    private var stepWidth: CGFloat {
        cardWidth + spacing
    }
    private var continuousIndex: Double { // Calculate a fluid index that changes mid-swipe
        Double(currentCenterIndex) - (Double(dragTranslation) / stepWidth)
    }
    private var activeIndex: Int {
        let index = Int(round(continuousIndex))
        return max(0, min(games.count - 1, index))
    }
    private var currentXOffset: CGFloat {
        let middleIndex = Double(games.count - 1) / 2.0
        // Base position based on the selection, plus the live drag movement
        let baseOffset = (middleIndex - Double(currentCenterIndex)) * stepWidth
        return baseOffset + dragTranslation
    }
    private func getCurrentYOffset(for distance: Double) -> CGFloat {
        return hasSelectedGame ? -400 : abs(distance * 15)
    }
    
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(Array(games.enumerated()), id: \.element.id) { index, game in
                
                let distance = Double(index) - continuousIndex
                let isCenter = abs(distance) < 0.5 // If distance is between -0.5 and 0.5, it's the primary card right now
                let yOffset = getCurrentYOffset(for: distance)
                
                CardView(frontImage: game.logoCard, cardHeight: cardHeight, rotation: isCenter ? 0 : -180)
                    .zIndex(Double(games.count) - abs(distance))
                    .rotationEffect(.degrees(distance * fanningAngle))
                    .offset(y: yOffset)
                    .onTapGesture {
                        if index == currentCenterIndex {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                                hasSelectedGame = true
                            }
                            //DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                userSelectedGame(index)  //parent view should handle exact parent view changes
                            //}
                        } else {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                currentCenterIndex = index
                            }
                            onActiveIndexChange(index)
                        }
                    }
            }
            .frame(width: cardWidth, height: cardHeight)
        }
        .offset(x: currentXOffset)
        .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.8), value: dragTranslation)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentCenterIndex)
        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: hasSelectedGame)
        .allowsHitTesting(!hasSelectedGame) // Disable interaction while opening submenu
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
                    
                    let newIndex = max(0, min(games.count - 1, currentCenterIndex + indexShift))
                    
                    if newIndex != currentCenterIndex {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            currentCenterIndex = newIndex
                        }
                        onActiveIndexChange(newIndex) //tell parent immediately when drag ends
                    } else {
                        // Edge case: If we drag a little bit but snap back to the same card,
                        // ensure the title is correct (in case it drifted during the drag)
                        onActiveIndexChange(newIndex)
                    }
                }
        )
    }
}
