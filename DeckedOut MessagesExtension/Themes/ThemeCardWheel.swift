//
//  ThemeCardWheel.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 5/19/26.
//

import SwiftUI

struct ThemeCardWheel: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motionSpeed: Double { reduceMotion ? 0.4 : 1.0 } //animations run at 40% speed (2.5x slower) when Reduce Motion is enabled
    let themes: [CardBackTheme]
    let showingThemes: Bool //drives the per-card flip in from the game wheel
    var onActiveIndexChange: (Int, Edge) -> Void // (themeIndex, direction the new title enters from)
    var onThemeSelected: (Int) -> Void

    private var cardWidth: CGFloat { 140 }
    private var cardHeight: CGFloat { 200 }
    private var spacing: CGFloat { -95 }
    private var stepWidth: CGFloat { cardWidth + spacing }
    private var fanningAngle: Double { 10 }
    private let visibleCount = 21 // Number of cards visible in the wheel at once

    @State private var currentCenterIndex: Int
    @State private var previousVirtualIndex: Int
    @State private var isDragging = false
    @GestureState private var dragTranslation: CGFloat = 0
    @State private var animatedOffset: CGFloat = 0 // Animated offset for flick momentum — decays to 0 as the cards settle

    init(themes: [CardBackTheme], initialIndex: Int = 0, showingThemes: Bool, onActiveIndexChange: @escaping (Int, Edge) -> Void, onThemeSelected: @escaping (Int) -> Void) {
        self.themes = themes
        self.showingThemes = showingThemes
        self.onActiveIndexChange = onActiveIndexChange
        self.onThemeSelected = onThemeSelected
        self._currentCenterIndex = State(initialValue: initialIndex)
        self._previousVirtualIndex = State(initialValue: initialIndex)
    }

    private var continuousIndex: Double { Double(currentCenterIndex) - (Double(dragTranslation) / stepWidth) - (Double(animatedOffset) / stepWidth) }
    private var activeIndex: Int { Int(round(continuousIndex)) }
    private var activeThemeTitle: String { themes[themeIndex(for: currentCenterIndex)].title }

    /// Maps any virtual index (can be negative or beyond themes.count) to a valid theme array index
    private func themeIndex(for virtualIndex: Int) -> Int {
        let count = themes.count
        return ((virtualIndex % count) + count) % count
    }

    /// Notifies the parent with the real theme index and the swipe direction based on virtual index movement
    private func notifyActiveChange(for virtualIndex: Int) {
        let direction: Edge = virtualIndex > previousVirtualIndex ? .trailing : .leading
        previousVirtualIndex = virtualIndex
        onActiveIndexChange(themeIndex(for: virtualIndex), direction)
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
        return abs(distance * 20)
    }
    
    /// Helper function to programmatically move the wheel
    private func moveWheel(by shift: Int, dragOffset: CGFloat = 0) {
        let newIndex = currentCenterIndex + shift
        animatedOffset = dragOffset + (CGFloat(shift) * stepWidth)
        currentCenterIndex = newIndex

        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).speed(motionSpeed)) {
            animatedOffset = 0
        }
        notifyActiveChange(for: newIndex)
    }

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(visibleVirtualIndices, id: \.self) { virtualIndex in
                let realIndex = themeIndex(for: virtualIndex)
                let theme = themes[realIndex]

                let distance = Double(virtualIndex) - continuousIndex
                let isCenter = abs(distance) < 0.5
                let yOffset = getCurrentYOffset(for: distance)

                let baseRotation: Double = isCenter ? 0 : 180
                // Theme wheel flips in opposite phase to the game wheel: starts already flipped away
                // when the game wheel is showing, lands at base rotation when themes are active.
                let flipRotation: Double = showingThemes ? 0 : 180

                // Both faces use the theme's card-back image so the card looks identical from either side.
                CardView(
                    frontImage: theme.logoCard,
                    backImageName: theme.logoCard,
                    cardHeight: cardHeight,
                    rotation: baseRotation + flipRotation
                )
                    .zIndex(Double(visibleCount) - abs(distance))
                    .rotationEffect(.degrees(distance * fanningAngle))
                    .offset(y: yOffset)
                    .shadow(color: .black.opacity(0.10), radius: 10, y: 20)
                    .onTapGesture {
                        if virtualIndex != currentCenterIndex {
                            // Set animatedOffset to keep cards visually in place, then animate to 0
                            animatedOffset = CGFloat(virtualIndex - currentCenterIndex) * stepWidth
                            currentCenterIndex = virtualIndex
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).speed(motionSpeed)) {
                                animatedOffset = 0
                            }
                            notifyActiveChange(for: virtualIndex)
                        } else { //user tapped the center card
                            onThemeSelected(realIndex)
                        }
                    }
            }
            .frame(width: cardWidth, height: cardHeight)
        }
        .offset(x: currentXOffset)
        .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.8).speed(motionSpeed), value: dragTranslation)
        .onChange(of: activeIndex) { _, newValue in
            if isDragging {
                notifyActiveChange(for: newValue)
            }
        }
        .sensoryFeedback(.selection, trigger: activeIndex)
        .gesture(
            DragGesture()
                .updating($dragTranslation) { value, state, _ in
                    if !isDragging { isDragging = true }
                    state = value.translation.width
                }
                .onEnded { value in // Predict where the scroll should land based on gesture speed and distance
                    isDragging = false

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

                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7).speed(motionSpeed)) {
                        animatedOffset = 0
                    }
                    notifyActiveChange(for: newIndex)
                }
        )
        // --- Accessibility Configuration ---
        .accessibilityElement(children: .ignore) // Ignores individual cards; only the wheel is focused
        .accessibilityLabel(Text("Theme Selection Carousel", comment: "VoiceOver accessibility label for the theme-selection carousel"))
        .accessibilityInputLabels([
            Text("Select Theme", comment: "Voice Control input label – select the current theme in the carousel"),
            Text("Select \(activeThemeTitle)", comment: "Voice Control input label – select the named theme, e.g. 'Select Sunset'"),
            Text("\(activeThemeTitle) Card", comment: "Voice Control input label – the active card in the theme carousel, e.g. 'Sunset Card'"),
            Text("Equip Theme", comment: "Voice Control input label – equip the current theme"),
            Text("Equip \(activeThemeTitle)", comment: "Voice Control input label – equip the named theme, e.g. 'Equip Sunset'"),
        ])
        .accessibilityValue(Text(verbatim: activeThemeTitle))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onThemeSelected(themeIndex(for: currentCenterIndex)) } //Default VoiceOver activation action
        .accessibilityScrollAction { edge in  // Voice Control: "Scroll Left / Scroll Right"
            if edge == .leading { moveWheel(by: -1) }
            else if edge == .trailing { moveWheel(by: 1) }
        }
        .accessibilityAdjustableAction { direction in // VoiceOver: Flick Up / Flick Down
            switch direction {
            case .increment: moveWheel(by: 1)
            case .decrement: moveWheel(by: -1)
            @unknown default: break
            }
        }
    }
}
