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
    
    var body: some View {
        Image(isFaceUp ? imageName : "cardBackRed")
            .resizable()
            .aspectRatio(0.7, contentMode: .fit)
            .frame(height: 145)
            .shadow(radius: 3)
    }
}
/*
struct DraggableCardView: View {
    let card: Card
    let isFaceUp: Bool
    let offset: CGSize
    let rotation: Angle
    let isDragging: Bool
    
    var body: some View {
        CardView(imageName: card.imageName, isFaceUp: isFaceUp)
            .offset(offset)
            .rotationEffect(rotation)
            .scaleEffect(isDragging ? 1.1 : 1.0)
            .shadow(radius: isDragging ? 6 : 3)
    }
}*/


struct FannedHandView: View {
    @Binding var cards: [Card]
    let isFaceUp: Bool
    var discardPileZone: CGRect? = nil
    
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
    
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(cards) { card in
                    
                let isDragging = draggedCard == card
                let index = cards.firstIndex(of: card)!
                let visualIndex = calculateVisualIndex(for: index)
                
                let angle = Angle.degrees(Double(visualIndex - cards.count/2) * fanningAngle)
                let yOffset = abs(Double(visualIndex - cards.count/2) * fanningOffset)
                let stride = cardWidth + spacing
                let xOffset = CGFloat(visualIndex - index) * stride
                    
                GeometryReader { geo in
                    let geoFrame = geo.frame(in: .global)
                    
                    Group {
                        if isFaceUp { //Player's hand!
                            CardView(imageName: card.imageName, isFaceUp: isFaceUp)
                                .rotationEffect(angle)
                                //.rotationEffect(isDragging ? calculateDragRotation(width: dragOffset.width) : angle)
                                .offset(x: isDragging ? 0 : xOffset, y: isDragging ? 0 : yOffset) //for the arc
                                .scaleEffect(isDragging ? 1.1 : 1.0)
                                .offset(isDragging ? dragOffset : .zero) //for dragging
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
                            
                        } else { //Opponent's hand! Can't drag these!
                            CardView(imageName: card.imageName, isFaceUp: isFaceUp)
                                .rotationEffect(.degrees(Double(index - cards.count / 2) * 4))
                                .offset(y: abs(Double(index - cards.count / 2) * 5))
                        }
                    }
                }
                .frame(width: cardWidth, height: cardHeight)
                .zIndex(isDragging ? 100 : Double(visualIndex))
                //.transition(.identity)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: predictedDropIndex)
            }
        }
        .frame(height: cardHeight)
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
        print("touch location", value.location)
        print("center of card", exactCenter)
        print("center of discard pile", discardPileZone!.midX, discardPileZone!.midY)
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
                    onDragEnded?(card, value.location)
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
        
        onDragEnded?(card, value.location)
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
    
    /*private func calculateDragRotation(width: CGFloat) -> Angle {
        let maxRotation: Double = 20.0
        let rotation = Double(width / 10)
        return .degrees(min(max(rotation, -maxRotation), maxRotation))
    }*/
}

extension FannedHandView {
    init(cards: [Card], isFaceUp: Bool) {
        self._cards = .constant(cards)  // Creates a constant binding
        self.isFaceUp = isFaceUp
    }
}
