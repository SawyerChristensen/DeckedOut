//
//  UIUtils.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 11/17/25.
//

import SwiftUI

extension Suit {
    var stringValue: String {
        switch self {
        case .spades: return "Spades"
        case .hearts: return "Hearts"
        case .diamonds: return "Diamonds"
        case .clubs: return "Clubs"
        }
    }
}

extension Rank {
    var stringValue: String {
        switch self {
        case .ace: return "ace"
        case .two: return "2"
        case .three: return "3"
        case .four: return "4"
        case .five: return "5"
        case .six: return "6"
        case .seven: return "7"
        case .eight: return "8"
        case .nine: return "9"
        case .ten: return "10"
        case .jack: return "jack"
        case .queen: return "queen"
        case .king: return "king"
        }
    }
}

extension Card {
    var imageName: String {
        "\(rank.stringValue)\(suit.stringValue)"
    }
}


struct CardView: View {
    let imageName: String
    let isFaceUp: Bool
    var animatableFlipAngle: Double = 0
        
        var body: some View {
            let effectiveRotation = animatableFlipAngle + (isFaceUp ? 0 : 180)
            
            ZStack {
                // BACK VIEW
                Image("cardBackRed")
                    .resizable()
                    .aspectRatio(0.7, contentMode: .fit)
                    .frame(height: 145)
                    .shadow(radius: 3)
                    .modifier(FlipOpacity(rotation: effectiveRotation + 180))
                
                // FRONT VIEW
                Image(imageName)
                    .resizable()
                    .aspectRatio(0.7, contentMode: .fit)
                    .frame(height: 145)
                    .shadow(radius: 3)
                    .modifier(FlipOpacity(rotation: effectiveRotation))
            }
            .rotation3DEffect(
                .degrees(effectiveRotation),
                axis: (x: 0.0, y: 1.0, z: 0.0) // Rotate around Y-axis
            )
        }
    
    private func shouldShowFront(angle: Double) -> Bool {
        let normalized = angle.remainder(dividingBy: 360)
        return abs(normalized) < 90
    }
}

struct FannedHandView: View {
    @Binding var cards: [Card]
    let isFaceUp: Bool
    var discardPileZone: CGRect? = nil
    var deckZone: CGRect? = nil
    let drewFromDiscard: Bool
    let drewFromDeck: Bool
    
    // Callbacks for zoning
    var onDragChanged: ((Card, CGPoint) -> Void)? = nil
    var onDragEnded: ((Card, CGPoint) -> Void)? = nil
    
    @State var draggedCard: Card?
    @State var dragStartIndex: Int?
    @State var dragOffset: CGSize = .zero
    
    // Constants
    private let cardWidth: CGFloat = 140 * 0.7
    private let cardHeight: CGFloat = 140
    private let spacing: CGFloat = -67
    private let fanningAngle: Double = 4
    private let fanningOffset: Double = 5
    
    @State private var predictedDropIndex: Int?
    
    // NEW: Track which card is animating from discard
    @State private var animatingCard: Card?
    @State private var animationOffset: CGSize = .zero
    @State private var animationRotationCorrection: Angle = .zero
    @State private var flipRotation: Double = 0
    
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(cards) { card in
                    
                let isDragging = draggedCard == card
                let isAnimating = animatingCard == card
                let index = cards.firstIndex(of: card)!
                let visualIndex = calculateVisualIndex(for: index)
                
                let angle = Angle.degrees(Double(visualIndex - cards.count/2) * fanningAngle)
                let yOffset = abs(Double(visualIndex - cards.count/2) * fanningOffset)
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
                    
                    Group {
                        if isFaceUp { //Player's hand!
                            CardView(imageName: card.imageName, isFaceUp: isFaceUp, animatableFlipAngle: isAnimating ? flipRotation : 0)
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
                                .onAppear {
                                    guard index == cards.count - 1 else { return }
                                    let sourceZone = drewFromDiscard ? discardPileZone : (drewFromDeck ? deckZone : nil)
                                    if let zone = sourceZone {
                                        animatingCard = card
                                        animateDraw(card: card, cardFrame: geoFrame, drawZone: zone, fanAngle: angle)
                                    }
                                }
                            
                        } else { //Opponent's hand! Can't drag these!
                            CardView(imageName: card.imageName, isFaceUp: isFaceUp)
                                .rotationEffect(.degrees(Double(index - cards.count / 2) * 4))
                                .offset(y: abs(Double(index - cards.count / 2) * 5))
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
        
        if drewFromDeck {
            flipRotation = 180
        } else {
            flipRotation = 0
        }
        
        // Set initial state
        animationOffset = offsetToDraw
        animationRotationCorrection = .degrees(0)
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            animationOffset = .zero
            animationRotationCorrection = fanAngle
            if drewFromDeck {
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
        // Logic allows gaps to open/close as you drag
        guard let startIndex = cards.firstIndex(of: card) else { return }
        
        let effectiveCardWidth = cardWidth + spacing
        // We use the binding dragOffset here
        let stepsMoved = Int(round(dragOffset.width / effectiveCardWidth))
        
        var newIndex = startIndex + stepsMoved
        newIndex = max(0, min(cards.count - 1, newIndex))
        
        if predictedDropIndex != newIndex {
            predictedDropIndex = newIndex
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        }
    }
    
    private func handleDragEnd(card: Card, value: DragGesture.Value, exactCenter: CGPoint) {
        // Check if dropped on discard pile
        if let discardPileZone = discardPileZone {
            let touchLocation = value.location
            
            if discardPileZone.contains(touchLocation) {
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
        }
        
        // Original logic for reordering within hand
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
        // We use max(0, height) to ensure negative drag doesn't break the math
        let progress = max(0, abs(height)) / rotationStopThreshold
        
        // 3. Invert the progress:
        // At height 0, factor is 1.0 (Full rotation effect)
        // At height 250, factor is 0.0 (No rotation)
        let rotationFactor = 1.0 - progress
        
        // 4. Apply the factor to the original angle
        return Angle.degrees(angle.degrees * rotationFactor)
    }
}

extension FannedHandView {
    init(cards: [Card], isFaceUp: Bool, drewFromDiscard: Bool, drewFromDeck: Bool) {
        self._cards = .constant(cards)  // Creates a constant binding
        self.isFaceUp = isFaceUp
        self.drewFromDiscard = drewFromDiscard
        self.drewFromDeck = drewFromDeck
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
