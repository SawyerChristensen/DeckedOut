//
//  GolfPlayerHandView.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 4/15/26.
//

import SwiftUI

struct GolfPlayerHandView: View {
    @EnvironmentObject var game: GolfManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motionSpeed: Double { reduceMotion ? 0.66 : 1.0 } //animations should run at 2/3 speed when "Reduce Motion" is enabled

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
    @State private var displayedCancelled: Set<Int> = []
    
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
                            let isCancelled = displayedCancelled.contains(index)

                            GeometryReader { geo in
                                let geoFrame = geo.frame(in: .global)

                                CardView(frontImage: card.imageName,
                                         rotation: isAnimating ? flipRotation : (isDeparting || isFaceUp ? 0 : -180))
                                    // Transforms
                                    .rotationEffect(isAnimating ? animationRotationCorrection : .zero)
                                    .scaleEffect(isDragging ? 1.1 : 1.0)
                                    .opacity(isCancelled ? 0.8 : 1.0)
                                    .animation(.easeInOut(duration: 0.3).speed(motionSpeed), value: isCancelled)
                                    .offset(isDeparting ? departingOffset : (isDragging ? dragOffset : .zero))
                                    .offset(isAnimating ? animationOffset : .zero)

                                    // Accessibility configuration
                                    .contentShape(Rectangle())
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityLabel(Text(accessibilityLabel(for: card, at: index, isFaceUp: isFaceUp)))
                                    .accessibilityInputLabels(accessibilityInputLabels(for: card, at: index, isFaceUp: isFaceUp))
                                    .accessibilityAddTraits(.isButton)
                                    .accessibilityAction { onCardTapped?(index) }

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
        .onAppear {
            displayedCancelled = game.playerCancelledIndices
        }
        .onChange(of: game.playerCancelledIndices) { _, new in
            // Defer past the placement reset so the .animation(value: isCancelled) doesn't pull the offset reset into its transaction
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                displayedCancelled = new
            }
        }
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
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).speed(motionSpeed)) {
            animationOffset = .zero
            if lastDrawSource == .deck {
                flipRotation = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 / motionSpeed) {
            animatingCard = nil
            flipRotation = 0
        }
    }

    private func accessibilityLabel(for card: Card, at index: Int, isFaceUp: Bool) -> String {
        let row = (index / columns) + 1
        let col = (index % columns) + 1
        if isFaceUp {
            return String(
                format: String(localized: "%@ of %@, row %lld column %lld", comment: "Voice Control label for a face-up Golf grid card, e.g. Queen of Hearts, row 1 column 2"),
                card.rank.localizedName,
                card.suit.localizedName,
                row,
                col
            )
        } else {
            return String(
                format: String(localized: "Face-down card, row %lld column %lld", comment: "Voice Control label for a face-down Golf grid card"),
                row,
                col
            )
        }
    }

    private func accessibilityInputLabels(for card: Card, at index: Int, isFaceUp: Bool) -> [Text] {
        let row = (index / columns) + 1
        let col = (index % columns) + 1
        let rowOrdinal = ordinal(row)
        let colOrdinal = ordinal(col)

        var labels: [Text] = [
            Text("Row \(row) column \(col)", comment: "Voice Control input label for a Golf grid card, e.g. row 1 column 2"),
            Text("Column \(col) row \(row)", comment: "Voice Control input label for a Golf grid card, e.g. column 2 row 1"),
            Text("\(rowOrdinal) row \(colOrdinal) column", comment: "Voice Control input label for a Golf grid card using ordinal words, e.g. first row second column"),
            Text("\(colOrdinal) column \(rowOrdinal) row", comment: "Voice Control input label for a Golf grid card using ordinal words, e.g. second column first row"),
            Text("the \(rowOrdinal) row \(colOrdinal) column", comment: "Voice Control input label for a Golf grid card prefixed with 'the', e.g. the first row second column"),
            Text("the \(colOrdinal) column \(rowOrdinal) row", comment: "Voice Control input label for a Golf grid card prefixed with 'the', e.g. the second column first row")
        ]

        if isFaceUp {
            let rank = card.rank.localizedName
            let suit = card.suit.localizedName
            let base = String(
                format: String(localized: "%@ of %@", comment: "Voice Control card name, e.g. Queen of Hearts"),
                rank, suit
            )
            let bare = "\(rank) \(suit)"
            labels.append(Text(verbatim: base))
            labels.append(Text("the \(base)", comment: "Voice Control input label for a card prefixed with the article 'the', e.g. 'the Queen of Hearts'"))
            labels.append(Text(verbatim: bare))
        }

        return labels
    }

    private func ordinal(_ n: Int) -> String {
        switch n {
        case 1: return String(localized: "first", comment: "Ordinal word used in Voice Control input labels (Golf grid positions)")
        case 2: return String(localized: "second", comment: "Ordinal word used in Voice Control input labels (Golf grid positions)")
        case 3: return String(localized: "third", comment: "Ordinal word used in Voice Control input labels (Golf grid positions)")
        default: return "\(n)"
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

