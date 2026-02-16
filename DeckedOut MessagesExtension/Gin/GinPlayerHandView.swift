//
//  FannedHandView.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 11/17/25.
//

import SwiftUI

struct PlayerHandView: View {
    @EnvironmentObject var game: GameManager
    
    //Passed Arguments
    @Binding var cards: [Card]
    var discardPileZone: CGRect? = nil
    var deckZone: CGRect? = nil
    let lastDrawSource: DrawSource
    
    // Callbacks for zoning
    var onDragChanged: ((Card, CGPoint) -> Void)? = nil
    var onDragEnded: ((Card, CGPoint) -> Void)? = nil
    
    // For dragging
    @State var draggedCard: Card?
    @State var dragStartIndex: Int?
    @State var dragOffset: CGSize = .zero
    @State private var predictedDropIndex: Int?
    
    // For animating from deck/discard
    @State private var animatingCard: Card?
    @State private var animationOffset: CGSize = .zero
    @State private var animationRotationCorrection: Angle = .zero
    @State private var flipRotation: Double = 0
    
    // Card sizing
    private var cardWidth: CGFloat { cards.count >= 10 ? 98 : 101.5 } // 140 * 0.7 & 145 * 0.7
    private var cardHeight: CGFloat { cards.count >= 10 ? 140 : 145 }
    private var spacing: CGFloat { cards.count >= 10 ? -72 : -66 }
    private var centerOffset: Double { Double(cards.count - 1) / 2.0 }

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(cards) { card in
                    
                let isDragging = draggedCard == card
                let isAnimating = animatingCard == card
                let index = cards.firstIndex(of: card)!
                let visualIndex = calculateVisualIndex(for: index)
                
                let angle = Angle.degrees((Double(visualIndex) - centerOffset) * 4) // fanningAngle = 4
                let yOffset = abs((Double(visualIndex) - centerOffset) * 5) //fanningOffset = 5
                let stride = cardWidth + spacing
                let xOffset = CGFloat(visualIndex - index) * stride
                    
                var finalRotation: Angle {
                    if isDragging {
                        return calculateDragRotation(height: dragOffset.height, angle: angle)
                    } else if isAnimating {
                        return animationRotationCorrection
                    } else {
                        return angle
                    }
                }
                
                GeometryReader { geo in
                    let geoFrame = geo.frame(in: .global)
                    
                    CardView(frontImage: card.imageName,
                             rotation: isAnimating ? flipRotation : 0)
                        .rotationEffect(finalRotation)
                        .offset(x: isDragging ? .zero : xOffset, y: isDragging ? .zero : yOffset) //for the arc
                        .scaleEffect(isDragging ? 1.1 : 1.0)
                        .offset(isDragging ? dragOffset : .zero) //for dragging
                        //.rotationEffect(isAnimating ? animationRotationCorrection : .degrees(0))
                        .offset(isAnimating ? animationOffset : .zero)
                        .gesture(
                            DragGesture(coordinateSpace: .global)
                                .onChanged { value in
                                    if draggedCard == nil {
                                        draggedCard = card
                                        predictedDropIndex = index
                                    }
                                    dragOffset = value.translation
                                    handleDragChange(card: card, value: value) //internal change
                                    onDragChanged?(card, value.location) //external change
                                }
                                .onEnded { value in
                                    let cardCenter = CGPoint(
                                        x: geoFrame.midX + value.translation.width,
                                        y: geoFrame.midY + value.translation.height
                                                                                )
                                    handleDragEnd(card: card, value: value, exactCenter: cardCenter) //internal change
                                    onDragEnded?(card, value.location) //external change
                                }
                        )
                        .onAppear { //could maybe change this to an onChange modifier, right now this works (when the view gets rerendered)
                            guard index == cards.count - 1 else { return }
                            let sourceZone: CGRect?
                                switch lastDrawSource {
                                case .deck: sourceZone = deckZone
                                case .discard: sourceZone = discardPileZone
                                case .none: sourceZone = nil
                                }
                            if let zone = sourceZone { //this functions as another "guard" type function. we only draw to the last index, and only draw if one of ^ becomes true
                                animatingCard = card
                                animateDraw(card: card, cardFrame: geoFrame, drawZone: zone, fanAngle: angle)
                            }
                        }
                            
                }
                .frame(width: cardWidth, height: cardHeight)
                .zIndex(isDragging ? 100 : Double(visualIndex))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: predictedDropIndex)
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: cards.count)
            }
        }
        .frame(height: cardHeight)
    }
    
    private func animateDraw(card: Card, cardFrame: CGRect, drawZone: CGRect, fanAngle: Angle) {
        // Calculate offset from card's natural position to discard pile
        let offsetToDraw = CGSize(
            width: drawZone.midX - cardFrame.midX,
            height: drawZone.midY - cardFrame.midY
        )
        
        if lastDrawSource == .deck {
            flipRotation = 180
        } else { //assuming .discard
            flipRotation = 0
        }
        
        // initial state
        animationOffset = offsetToDraw
        animationRotationCorrection = .degrees(0)
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            animationOffset = .zero
            animationRotationCorrection = fanAngle
            if lastDrawSource == .deck {
                flipRotation = 0
            }
        }
            
        // Clear animation state after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            animatingCard = nil
            flipRotation = 0
        }
    }
    
    private func handleDragChange(card: Card, value: DragGesture.Value) {
        guard let startIndex = cards.firstIndex(of: card) else { return }
        let effectiveCardWidth = cardWidth + spacing
        let stepsMoved = Int(round(dragOffset.width / effectiveCardWidth))
        var newIndex = startIndex + stepsMoved
        newIndex = max(0, min(cards.count - 1, newIndex))
        
        if predictedDropIndex != newIndex {
            predictedDropIndex = newIndex
            SoundManager.instance.playCardReorder()
        }
    }
    
    private func handleDragEnd(card: Card, value: DragGesture.Value, exactCenter: CGPoint) {
        // Check if card dropped on discard pile, if user is in discard phase
        if let discardPileZone = discardPileZone,
            discardPileZone.contains(value.location),
            game.phase == .discardPhase { //is checking the phase a potential race condition?
            
            game.indexDiscardedFrom = cards.firstIndex(of: card) //this might be redundant
            
            // Calculate the offset needed to reach discard from card's START position
            let cardStartLocation = CGPoint(
                x: exactCenter.x - dragOffset.width,
                y: exactCenter.y - dragOffset.height
            )
            
            let targetOffset = CGSize(
                width: discardPileZone.midX - cardStartLocation.x,
                height: discardPileZone.midY - cardStartLocation.y
            )
            
            // Animate to discard pile
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                dragOffset = targetOffset
            }
            
            // After animation, notify parent to actually move the card
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                draggedCard = nil
                dragOffset = .zero
                predictedDropIndex = nil
            }
            return
        }
        
        // Card going back to hand, reorder hand with new card position
        if let sourceIndex = cards.firstIndex(of: card),
           let targetIndex = predictedDropIndex {
            if sourceIndex != targetIndex {
                withAnimation(.spring()) {
                    cards.move(fromOffsets: IndexSet(integer: sourceIndex),
                        toOffset: targetIndex > sourceIndex ? targetIndex + 1 : targetIndex)
                }
            }
        }
        
        draggedCard = nil
        dragOffset = .zero
        predictedDropIndex = nil
    }
    
    private func calculateVisualIndex(for realIndex: Int) -> Int {
        guard let draggedCard,
              let sourceIndex = cards.firstIndex(of: draggedCard),
              let targetIndex = predictedDropIndex else {
            return realIndex
        }
        if realIndex == sourceIndex { return targetIndex }
        if sourceIndex < targetIndex {
            if realIndex > sourceIndex && realIndex <= targetIndex { return realIndex - 1 }
        } else if sourceIndex > targetIndex {
            if realIndex >= targetIndex && realIndex < sourceIndex { return realIndex + 1 }
        }
        return realIndex
    }
    
    private func calculateDragRotation(height: CGFloat, angle: Angle) -> Angle {
        // 1. The height at which the card should be fully straight (0 degrees)
        let rotationStopThreshold: CGFloat = 250.0
        
        // 2. Calculate progress from 0.0 to 1.0 based on the height
        let progress = min(max(0, abs(height)) / rotationStopThreshold, 1)
        
        // 3. Invert the progress:
        // At height 0, factor is 1.0 (Full rotation effect)
        // At height 250, factor is 0.0 (No rotation)
        let rotationFactor = 1.0 - progress
        
        // 4. Apply the factor to the original angle
        return Angle.degrees(angle.degrees * rotationFactor)
    }
}

extension PlayerHandView {
    init(cards: [Card], discardPileZone: CGRect, deckZone: CGRect, lastDrawSource: DrawSource) {
        self._cards = .constant(cards)  // Creates a constant binding
        self.discardPileZone = discardPileZone
        self.deckZone = deckZone
        self.lastDrawSource = lastDrawSource
    }
}

struct FlipOpacity: AnimatableModifier {
    var rotation: Double
    
    // This tells SwiftUI: "Interpolate this number, and rebuild the view every time it changes"
    var animatableData: Double {
        get { rotation }
        set { rotation = newValue }
    }
    
    func body(content: Content) -> some View {
        // Normalize angle to -180...180
        let normalized = rotation.remainder(dividingBy: 360)
        
        // Hard cutoff: If within 90 degrees of "center", it's visible.
        // Otherwise, instant 0 opacity.
        let isVisible = abs(normalized) < 90
        
        content
            .opacity(isVisible ? 1 : 0)
    }
}
