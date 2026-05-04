//
//  GolfPlayerHandView.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 4/15/26.
//

import SwiftUI

struct GolfPlayerHandView: View {
    @EnvironmentObject var game: GolfManager
    
    //Passed Arguments
    @Binding var cards: [Card]
    var faceUpIndices: Set<Int> = []
    var discardPileZone: CGRect? = nil
    var deckZone: CGRect? = nil
    let lastDrawSource: DrawSource
    
    // Departing card animation (driven by parent)
    var departingIndex: Int? = nil
    var departingOffset: CGSize = .zero

    // Callbacks
    var onDragChanged: ((Card, CGPoint) -> Void)? = nil
    var onDragEnded: ((Card, CGPoint) -> Void)? = nil
    var onCardTapped: ((Int) -> Void)? = nil
    var onSlotFrameChanged: ((Int, CGRect) -> Void)? = nil
    
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
    private let columns = 3
    private let rows = 2
    private let cardWidth: CGFloat = 91
    private let cardHeight: CGFloat = 130
    private let gridSpacingH: CGFloat = 24
    private let gridSpacingV: CGFloat = 12

    var body: some View {
        VStack(spacing: gridSpacingV) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: gridSpacingH) {
                    ForEach(0..<columns, id: \.self) { col in
                        let index = row * columns + col
                        
                        if index < cards.count {
                            let card = cards[index]
                            let isDragging = draggedCard == card
                            let isAnimating = animatingCard == card
                            let isDeparting = departingIndex == index
                            let isFaceUp = faceUpIndices.contains(index)
                            let isCancelled = game.playerCancelledIndices.contains(index)

                            GeometryReader { geo in
                                let geoFrame = geo.frame(in: .global)

                                CardView(frontImage: card.imageName,
                                         rotation: isAnimating ? flipRotation : (isDeparting || isFaceUp ? 0 : -180))
                                    .rotationEffect(isAnimating ? animationRotationCorrection : .zero)
                                    .scaleEffect(isDragging ? 1.1 : 1.0)
                                    .opacity(isCancelled ? 0.8 : 1.0)
                                    .animation(.easeInOut(duration: 0.3), value: isCancelled)
                                    .offset(isDeparting ? departingOffset : (isDragging ? dragOffset : .zero))
                                    .offset(isAnimating ? animationOffset : .zero)
                                    .onTapGesture {
                                        onCardTapped?(index)
                                    }
                                    .gesture(
                                        DragGesture(coordinateSpace: .global)
                                            .onChanged { value in
                                                if draggedCard == nil {
                                                    draggedCard = card
                                                }
                                                dragOffset = value.translation
                                                onDragChanged?(card, value.location)
                                            }
                                            .onEnded { value in
                                                onDragEnded?(card, value.location)
                                                draggedCard = nil
                                                dragOffset = .zero
                                            }
                                    )
                                    .background(
                                        GeometryReader { slotGeo in
                                            Color.clear
                                                .onAppear { onSlotFrameChanged?(index, slotGeo.frame(in: .global)) }
                                                .onChange(of: slotGeo.frame(in: .global)) { _, newFrame in
                                                    onSlotFrameChanged?(index, newFrame)
                                                }
                                        }
                                    )
                                    .onAppear {
                                        guard index == cards.count - 1 else { return }
                                        let sourceZone: CGRect?
                                        switch lastDrawSource {
                                        case .deck: sourceZone = deckZone
                                        case .discard: sourceZone = discardPileZone
                                        case .none: sourceZone = nil
                                        }
                                        if let zone = sourceZone {
                                            animatingCard = card
                                            animateDraw(card: card, cardFrame: geoFrame, drawZone: zone)
                                        }
                                    }
                            }
                            .frame(width: cardWidth, height: cardHeight)
                            .zIndex(isDragging ? 100 : 0)
                        }
                    }
                }
            }
        }
        .frame(height: cardHeight * CGFloat(rows) + gridSpacingV)
    }
    
    private func animateDraw(card: Card, cardFrame: CGRect, drawZone: CGRect) {
        let offsetToDraw = CGSize(
            width: drawZone.midX - cardFrame.midX,
            height: drawZone.midY - cardFrame.midY
        )
        
        if lastDrawSource == .deck {
            flipRotation = 180
        } else {
            flipRotation = 0
        }
        
        animationOffset = offsetToDraw
        animationRotationCorrection = .zero
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            animationOffset = .zero
            if lastDrawSource == .deck {
                flipRotation = 0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            animatingCard = nil
            flipRotation = 0
        }
    }
}

extension GolfPlayerHandView {
    init(cards: [Card], faceUpIndices: Set<Int>, discardPileZone: CGRect, deckZone: CGRect, lastDrawSource: DrawSource) {
        self._cards = .constant(cards)
        self.faceUpIndices = faceUpIndices
        self.discardPileZone = discardPileZone
        self.deckZone = deckZone
        self.lastDrawSource = lastDrawSource
        self.departingIndex = nil
        self.departingOffset = .zero
        self.onCardTapped = nil
        self.onSlotFrameChanged = nil
    }
}

