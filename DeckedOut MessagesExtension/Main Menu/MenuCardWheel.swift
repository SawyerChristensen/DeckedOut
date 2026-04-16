//
//  MenuCardWheel.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 2/17/26.
//

import SwiftUI

struct MenuCardWheel: View {
    let games: [MenuGame]
    var onActiveIndexChange: (Int, Edge) -> Void // (gameIndex, direction the new title enters from)
    var userSelectedGame: (Int) -> Void
    @Binding var hasSelectedGame: Bool //should get triggered at the same time userSelectedGame is called
    
    init(games: [MenuGame], onActiveIndexChange: @escaping (Int, Edge) -> Void, userSelectedGame: @escaping (Int) -> Void, hasSelectedGame: Binding<Bool>) {
        self.games = games
        self.onActiveIndexChange = onActiveIndexChange
        self.userSelectedGame = userSelectedGame
        self._hasSelectedGame = hasSelectedGame
    }
    
    private var cardWidth: CGFloat { hasSelectedGame ? 175 : 140 }
    private var cardHeight: CGFloat { hasSelectedGame ? 250 : 200 }
    private var spacing: CGFloat { hasSelectedGame ? -30 : -95 }
    private var stepWidth: CGFloat { cardWidth + spacing }
    private var fanningAngle: Double { hasSelectedGame ? 16 : 10 }
    private let visibleCount = 15 // Number of cards visible in the wheel at once
    
    @State private var currentCenterIndex: Int = 0 //the default game that is shown when opening the main menu
    @State private var previousVirtualIndex: Int = 0 // Tracks previous virtual index so we can determine swipe direction
    @State private var isDragging = false
    @GestureState private var dragTranslation: CGFloat = 0 //to track the drag amount while it's happening.
    @State private var animatedOffset: CGFloat = 0 // Animated offset for flick momentum — decays to 0 as the cards settle
    
    private var continuousIndex: Double { Double(currentCenterIndex) - (Double(dragTranslation) / stepWidth) - (Double(animatedOffset) / stepWidth) }
    private var activeIndex: Int { Int(round(continuousIndex)) }
    
    /// Maps any virtual index (can be negative or beyond games.count) to a valid game array index
    private func gameIndex(for virtualIndex: Int) -> Int {
        let count = games.count
        return ((virtualIndex % count) + count) % count
    }
    
    /// Notifies the parent with the real game index and the swipe direction based on virtual index movement
    private func notifyActiveChange(for virtualIndex: Int) {
        let direction: Edge = virtualIndex > previousVirtualIndex ? .trailing : .leading
        previousVirtualIndex = virtualIndex
        onActiveIndexChange(gameIndex(for: virtualIndex), direction)
    }
    
    /// The virtual indices of the cards currently visible in the wheel
    private var visibleVirtualIndices: [Int] {
        let half = visibleCount / 2
        return Array((currentCenterIndex - half)...(currentCenterIndex + half))
    }
    
    private var currentXOffset: CGFloat {
        dragTranslation + animatedOffset
    }
    private func getCurrentYOffset(for distance: Double) -> CGFloat {
        return hasSelectedGame ? -500 : abs(distance * 20)
    }
    
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(visibleVirtualIndices, id: \.self) { virtualIndex in
                let realIndex = gameIndex(for: virtualIndex)
                let game = games[realIndex]
                
                let distance = Double(virtualIndex) - continuousIndex
                let isCenter = abs(distance) < 0.5 // If distance is between -0.5 and 0.5, it's the primary card right now
                let yOffset = getCurrentYOffset(for: distance)
                
                CardView(frontImage: game.logoCard, cardHeight: cardHeight, rotation: isCenter ? 0 : 180)
                    .zIndex(Double(visibleCount) - abs(distance))
                    .rotationEffect(.degrees(distance * fanningAngle))
                    .offset(y: yOffset)
                    .onTapGesture {
                        if virtualIndex == currentCenterIndex {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                                hasSelectedGame = true
                            }
                            userSelectedGame(realIndex)  //parent view should handle exact parent view changes
                        } else {
                            // Set animatedOffset to keep cards visually in place, then animate to 0
                            animatedOffset = CGFloat(virtualIndex - currentCenterIndex) * stepWidth
                            currentCenterIndex = virtualIndex
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                animatedOffset = 0
                            }
                            notifyActiveChange(for: virtualIndex)
                        }
                    }
            }
            .frame(width: cardWidth, height: cardHeight)
        }
        .offset(x: currentXOffset)
        .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.8), value: dragTranslation)
        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: hasSelectedGame)
        .allowsHitTesting(!hasSelectedGame) // Disable interaction while opening submenu
        .onChange(of: activeIndex) { _, newValue in
            if isDragging {
                notifyActiveChange(for: newValue)
            }
        }
        .sensoryFeedback(.selection, trigger: activeIndex)
        .gesture(
            DragGesture()
                .updating($dragTranslation) { value, state, _ in // Update the translation while the drag is active
                    if !isDragging { isDragging = true }
                    state = value.translation.width
                }
                .onEnded { value in  // Predict where the scroll should land based on gesture speed and distance
                    isDragging = false
                    
                    let verticalMove = value.translation.height
                    let horizontalMove = value.translation.width
                    let verticalVelocity = value.predictedEndTranslation.height
                    
                    let isUpward = verticalMove < -50 || verticalVelocity < -150 // Check if the movement is strongly upward
                    let isPrimarilyVertical = abs(verticalMove) > abs(horizontalMove) * 1.5 //Check if the gesture is PRIMARILY vertical (avoids diagonals)
                    if isUpward && isPrimarilyVertical {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                            hasSelectedGame = true
                        }
                        userSelectedGame(gameIndex(for: currentCenterIndex))
                        return // Exit early if vertical selection swipe
                    }
                    
                    let maxFlickCards = 5 // Cap how far a single flick can travel
                    let predictedDrag = value.predictedEndTranslation.width
                    let rawShift = Int(round(-predictedDrag / stepWidth))
                    let indexShift = max(-maxFlickCards, min(maxFlickCards, rawShift))
                    
                    let newIndex = currentCenterIndex + indexShift // No clamping — infinite loop!
                    
                    // Capture the drag position so the visual position doesn't jump when
                    // @GestureState resets dragTranslation to 0 and currentCenterIndex changes.
                    // animatedOffset temporarily holds the visual displacement, then animates to 0.
                    let dragOffset = value.translation.width
                    animatedOffset = dragOffset + CGFloat(currentCenterIndex - newIndex) * stepWidth
                    currentCenterIndex = newIndex
                    
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        animatedOffset = 0
                    }
                    notifyActiveChange(for: newIndex)
                }
        )
    }
}
