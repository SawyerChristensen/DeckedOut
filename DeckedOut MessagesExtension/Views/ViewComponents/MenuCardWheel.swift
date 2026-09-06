//
//  MenuCardWheel.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 2/17/26.
//

import SwiftUI

/// The main menu's hand of cards — one hand, serving both carousels.
///
/// There are 21 card slots and they never move, are never rebuilt, and are never swapped for another
/// set. Scrolling changes which content each slot carries; opening the theme picker turns the whole
/// hand over (see ``MenuFlipCard``) and changes which *carousel* the slots read from. That is the
/// whole model.
///
/// This used to be two wheels — this one and a `ThemeCardWheel` — stacked in a `ZStack`, each with
/// its own 21 cards, its own centre index, its own drag gesture and its own settle spring, with the
/// transition done by fading one out and the other in at the halfway point of a shared rotation.
/// Three things were wrong with that and none of them were fixable by tuning:
///
/// * Two hands with different item counts and different centre indices fan out differently, so the
///   card you were looking at was never quite where its replacement appeared. They could not be made
///   to line up, because they were not the same cards.
/// * Which artwork was on screen depended on a wheel-level opacity cutoff, two more inside every
///   card, and 21 rotations all crossing 90° on the same frame. Anything left mid-flight by a swipe
///   broke that agreement and put the wrong face on screen.
/// * Re-centring the theme carousel on the equipped theme meant *moving* a wheel, which had to be
///   hidden inside the flip, which is what made the cards either side of a swipe misbehave.
///
/// With one hand, the first is impossible by construction, the second lives inside a single
/// `Animatable` card, and the third is an integer (`themeOffset`) rather than a movement.
struct MenuCardWheel: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motionSpeed: Double { reduceMotion ? 0.4 : 1.0 } //animations run at 40% speed (2.5x slower) when Reduce Motion is enabled
    @ObservedObject private var currentTheme = CurrentTheme.shared

    let games: [MenuGame]
    let themes: [DeckTheme]
    /// Which carousel the hand is currently showing. Turning this over is the menu → themes flip.
    let showingThemes: Bool
    /// The equipped theme. The picker re-centres on it every time it opens.
    let selectedThemeIndex: Int

    var onActiveGameChange: (Int, Edge) -> Void // (gameIndex, direction the new title enters from)
    var onActiveThemeChange: (Int, Edge) -> Void // (themeIndex, direction the new title enters from)
    var userSelectedGame: (Int) -> Void
    var onThemeSelected: (Int) -> Void
    @Binding var hasSelectedGame: Bool //should get triggered at the same time userSelectedGame is called

    // MARK: - Geometry

    private let restingCardWidth: CGFloat = 140
    private let restingSpacing: CGFloat = -95
    private var cardWidth: CGFloat { hasSelectedGame ? 175 : restingCardWidth }
    private var cardHeight: CGFloat { hasSelectedGame ? 250 : 200 }
    private var spacing: CGFloat { hasSelectedGame ? -30 : restingSpacing }
    /// Pixels of scroll per slot, and the conversion between `position` and `.offset(x:)`.
    ///
    /// Pinned to the resting geometry rather than the live one. The wheel is only ever scrolled
    /// while it is at rest — `allowsHitTesting` goes off the moment a game is picked — so this is
    /// the number every scroll already ran at, but pinning it means the widening the selection
    /// brings (45pt per slot to 145) cannot rescale a position that is still in flight.
    private var stepWidth: CGFloat { restingCardWidth + restingSpacing }
    /// The fan the hand holds at rest. Selecting a game *adds* `selectionFanBoost` on a separate
    /// modifier rather than widening this one — see `selectionLift` for why that split matters.
    private let restingFanAngle: Double = 10
    /// Extra fan the cards take on as they rise into the submenu, on top of `restingFanAngle`.
    private let selectionFanBoost: Double = 6
    /// How far the hand travels up and off screen when a game is selected.
    ///
    /// This, `selectionFanBoost` and the card size/spacing changes are the *only* things the
    /// selection animates, and each of them lives on a modifier the settle spring never touches.
    /// That separation is deliberate: SwiftUI springs preserve velocity when they're retargeted
    /// mid-flight, so folding the lift into the same `.offset(y:)` the flick settle is already
    /// animating made a tap during the settle launch the hand with whatever speed the settle
    /// happened to be carrying — the "fans up MUCH faster than if I wait" case. On its own
    /// modifier the lift always starts from rest, so the fan-up runs at one speed every time.
    private let selectionLift: CGFloat = -500
    private let visibleCount = 21 // Number of card slots in the hand

    // MARK: - State

    @State private var currentCenterIndex: Int = 0 //which slot is centred; shared by both carousels
    @State private var previousVirtualIndex: Int = 0 // Tracks previous slot so we can determine swipe direction
    @State private var isDragging = false
    @GestureState private var dragTranslation: CGFloat = 0 //to track the drag amount while it's happening.
    @State private var animatedOffset: CGFloat = 0 // Animated offset for flick momentum — decays to 0 as the cards settle

    /// Slot → games index. Re-based when the picker closes so the game the player was on comes back
    /// under the centre slot without the hand having to travel back to where it started.
    @State private var gameOffset: Int = 0
    /// Slot → themes index. Re-based when the picker opens so the equipped theme lands under the
    /// centre slot. This is all "re-centre on the selected theme" costs now: one integer, changed
    /// while the hand is still square-on to the games side and no card is reading a theme index yet.
    @State private var themeOffset: Int = 0
    /// The game that was centred when the picker opened, so closing it can re-base back onto it.
    @State private var gameIndexBeforeThemes: Int = 0

    // MARK: - Carousel mapping

    /// Wraps any slot index — which runs off in both directions forever — into a real array index.
    private func wrap(_ index: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return ((index % count) + count) % count
    }

    private func gameIndex(for slot: Int) -> Int { wrap(slot + gameOffset, count: games.count) }
    private func themeIndex(for slot: Int) -> Int { wrap(slot + themeOffset, count: themes.count) }

    private var activeGameIndex: Int { gameIndex(for: currentCenterIndex) }
    private var activeThemeIndex: Int { themeIndex(for: currentCenterIndex) }
    private var activeGameTitle: String { games[activeGameIndex].displayTitle }
    private var activeThemeTitle: String { themes[activeThemeIndex].title }

    private var continuousIndex: Double { Double(currentCenterIndex) - (Double(dragTranslation) / stepWidth) - (Double(animatedOffset) / stepWidth) }
    private var activeIndex: Int { Int(round(continuousIndex)) }

    /// The slots the hand is made of.
    private var visibleVirtualIndices: [Int] {
        let half = visibleCount / 2
        return Array((currentCenterIndex - half)...(currentCenterIndex + half))
    }

    /// The card's height in the resting fan, and *only* that.
    ///
    /// Nothing about the selection may be folded in here — not the lift, and not the flattening of
    /// the arc either. This modifier is the settle spring's; a card off the centre is arcing under
    /// it whenever the hand is moving, so any selection value read from here is a target swapped on
    /// a spring that is already in flight, and SwiftUI hands the replacement the velocity it had.
    /// That is the same trap `selectionLift` describes, and it caught this offset for longer: the
    /// arc used to collapse to 0 here on selection, which meant the outer cards — the only ones with
    /// an arc to collapse — inherited the settle's velocity and rose faster after a flick than from
    /// rest, while the centre card, sitting at `distance ≈ 0` with no arc and so no spring in
    /// flight, rose at the same speed either way. The flattening now rides out with the lift.
    private func getCurrentYOffset(for distance: Double) -> CGFloat {
        return abs(distance * 20)
    }

    /// Notifies the parent with the real index in whichever carousel is showing, and the swipe
    /// direction based on slot movement.
    private func notifyActiveChange(for slot: Int) {
        let direction: Edge = slot > previousVirtualIndex ? .trailing : .leading
        previousVirtualIndex = slot
        if showingThemes {
            onActiveThemeChange(themeIndex(for: slot), direction)
        } else {
            onActiveGameChange(gameIndex(for: slot), direction)
        }
    }

    // MARK: - Animation

    /// The one spring every wheel movement settles on, however it was started.
    ///
    /// It has to be the same spring the `.animation(_:value: dragTranslation)` modifier below uses.
    /// A flick changes `dragTranslation` (to zero) in the same update `moveWheel` runs in, so that
    /// modifier takes over the subtree and its spring is what the settle actually runs at — while a
    /// tap on an off-centre card, or a Voice Control scroll, changes no `dragTranslation` and runs
    /// at whatever `moveWheel` asked for. With two different springs the hand visibly settled at
    /// two different speeds depending on how it was nudged.
    private var settleAnimation: Animation {
        .interactiveSpring(response: 0.4, dampingFraction: 0.8).speed(motionSpeed)
    }

    private var selectionAnimation: Animation {
        .spring(response: 0.6, dampingFraction: 0.7).speed(motionSpeed)
    }

    /// Helper function to programmatically move the wheel
    private func moveWheel(by shift: Int, dragOffset: CGFloat = 0) {
        let newIndex = currentCenterIndex + shift
        animatedOffset = dragOffset + (CGFloat(shift) * stepWidth)
        currentCenterIndex = newIndex

        withAnimation(settleAnimation) {
            animatedOffset = 0
        }
        notifyActiveChange(for: newIndex)
    }

    private func selectCentredGame() {
        withAnimation(selectionAnimation) {
            hasSelectedGame = true
        }
        userSelectedGame(activeGameIndex) //parent view should handle exact parent view changes
    }

    // MARK: - Position

    /// Re-runs the hand on every frame of a scroll, with the in-between value of the wheel's
    /// position.
    ///
    /// This is `MenuFlipCard`'s trick one level up, and for the same reason. Without it, a scroll
    /// evaluates the hand exactly once — at the position the wheel is *going* to end at — and
    /// SwiftUI is left to spring each card from the arc height it was drawn at to the arc height it
    /// will have. That is 21 vertical springs, one per card, running alongside the horizontal one
    /// and answerable to nothing. Springs keep their velocity when they are retargeted, so swiping
    /// left and right quickly pumps every one of those springs: each flick retargets them mid-swing
    /// and hands them the speed they already had. Tap while that energy is still in the hand and it
    /// adds straight into the fan-up, because it is pointed the same way — up. The centre card sits
    /// where the arc is flat, has no vertical spring of its own to pump, and so was the one card
    /// that always rose at the right speed.
    ///
    /// With the arc read off `position` instead, there is one spring in the wheel and it is
    /// horizontal. The arc, the fan angle, which card is face up and the scroll offset are all
    /// derived from that single number in the same evaluation — nothing vertical is animating on
    /// its own, so there is no vertical velocity to bank and none to leak into the rise.
    private struct WheelPosition<Content: View>: View, Animatable {
        var position: Double
        @ViewBuilder var content: (Double) -> Content

        var animatableData: Double {
            get { position }
            set { position = newValue }
        }

        var body: some View { content(position) }
    }

    // MARK: - Body

    var body: some View {
        WheelPosition(position: continuousIndex) { position in
            HStack(spacing: spacing) {
                ForEach(visibleVirtualIndices, id: \.self) { slot in
                    let distance = Double(slot) - position
                    // Read off the settled position, not the live one, so a flick turns the card it
                    // is heading for face up as it comes in — rather than flipping every card it
                    // passes on the way. Dragging is unaffected either way: `continuousIndex` tracks
                    // the finger, so mid-drag these are the same number.
                    let isCenter = abs(Double(slot) - continuousIndex) < 0.5 // If distance is between -0.5 and 0.5, it's the primary card right now
                    let yOffset = getCurrentYOffset(for: distance)

                    MenuFlipCard(
                        // Only the centre card is turned face up; the rest of the hand is face down.
                        spin: isCenter ? 0 : 180,
                        // Shared by every card, so the whole hand turns over as one piece and every card
                        // reaches edge-on — and therefore swaps its artwork — on the same frame. Negative
                        // so the hand turns the same way the header title does (`mainTitle` rotates to
                        // -180 on the way into the picker): right on the way in, back left on the way out.
                        menuFlip: showingThemes ? -180 : 0,
                        game: games[gameIndex(for: slot)],
                        themeBackName: themes[themeIndex(for: slot)].logoCard,
                        equippedBackName: currentTheme.selectedName,
                        cardHeight: cardHeight
                    )
                    .zIndex(Double(visibleCount) - abs(distance))
                    // Resting fan — owned by the drag/flick settle.
                    .rotationEffect(.degrees(distance * restingFanAngle))
                    .offset(y: yOffset)
                    // Selection — its own modifiers, so the fan-up never inherits the settle's velocity.
                    // Cancelling `yOffset` here rather than zeroing it above is what keeps that true:
                    // this offset is a flat 0 the whole time the hand is at rest, whatever the settle is
                    // doing to the arc, so the rise always starts from a standstill.
                    .rotationEffect(.degrees(hasSelectedGame ? distance * selectionFanBoost : 0))
                    .offset(y: hasSelectedGame ? selectionLift - yOffset : 0)
                    .shadow(color: .black.opacity(0.10), radius: 10, y: 20)
                    .onTapGesture {
                        if slot == currentCenterIndex {
                            if showingThemes {
                                onThemeSelected(activeThemeIndex)
                            } else {
                                selectCentredGame()
                            }
                        } else {
                            moveWheel(by: slot - currentCenterIndex)
                        }
                    }
                }
                .frame(width: cardWidth, height: cardHeight)
            }
            // The same number the arc and the fan are read from, in pixels — not a second thing to
            // animate. Identical to the old `dragTranslation + animatedOffset`, by construction.
            .offset(x: (Double(currentCenterIndex) - position) * stepWidth)
        }
        // Selection sits *inside* the drag animation on purpose. When a value changes,
        // `.animation(_:value:)` overrides the animation for everything below it, so of two nested
        // ones the inner wins — and a swipe *up* to pick a game changes both values in the same
        // update. With these the other way round the drag's settle spring drove the fan-up, so
        // selecting by swipe rose at a different speed than selecting by tap.
        .animation(selectionAnimation, value: hasSelectedGame)
        .animation(settleAnimation, value: dragTranslation)
        .allowsHitTesting(!hasSelectedGame) // Disable interaction while opening submenu
        .onChange(of: showingThemes) { _, nowShowingThemes in
            // Both of these re-base a carousel onto the slot the hand is *already* sitting on, so
            // nothing moves and no card changes which way it is facing. Each one is applied while
            // the hand is still square-on to the other carousel, so no card is reading the offset
            // being changed. Compare the old design, where the equivalent was a wheel movement made
            // in the same update as the flip: that changed which card was face up at the same
            // moment the flip changed how far every card had turned, and the two cards either side
            // of the swap came out with a 360° change and a 0° change instead of 180° each — the
            // "every card flips correctly except the one I swiped to and the one I swiped from" bug.
            if nowShowingThemes {
                gameIndexBeforeThemes = activeGameIndex
                themeOffset = wrap(selectedThemeIndex - currentCenterIndex, count: themes.count)
            } else {
                gameOffset = wrap(gameIndexBeforeThemes - currentCenterIndex, count: games.count)
            }
        }
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

                    if !showingThemes { // Swiping a card up out of the hand picks that game
                        let verticalMove = value.translation.height
                        let horizontalMove = value.translation.width
                        let verticalVelocity = value.predictedEndTranslation.height

                        let isUpward = verticalMove < -50 || verticalVelocity < -150 // Check if the movement is strongly upward
                        let isPrimarilyVertical = abs(verticalMove) > abs(horizontalMove) * 1.5 //Check if the gesture is PRIMARILY vertical (avoids diagonals)
                        if isUpward && isPrimarilyVertical {
                            selectCentredGame()
                            return // Exit early if vertical selection swipe
                        }
                    }

                    let maxFlickCards = 5 // Cap how far a single flick can travel
                    let predictedDrag = value.predictedEndTranslation.width
                    let rawShift = Int(round(-predictedDrag / stepWidth))
                    let indexShift = max(-maxFlickCards, min(maxFlickCards, rawShift))

                    moveWheel(by: indexShift, dragOffset: value.translation.width)
                }
        )
        // --- Accessibility Configuration ---
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(showingThemes
            ? Text("Theme Selection Carousel", comment: "VoiceOver accessibility label for the theme-selection carousel")
            : Text("Game Selection Carousel", comment: "VoiceOver accessibility label for the main menu game-selection carousel"))
        .accessibilityInputLabels(showingThemes
            ? [
                Text("Select Theme", comment: "Voice Control input label – select the current theme in the carousel"),
                Text("Select \(activeThemeTitle)", comment: "Voice Control input label – select the named theme, e.g. 'Select Sunset'"),
                Text("\(activeThemeTitle) Card", comment: "Voice Control input label – the active card in the theme carousel, e.g. 'Sunset Card'"),
                Text("Equip Theme", comment: "Voice Control input label – equip the current theme"),
                Text("Equip \(activeThemeTitle)", comment: "Voice Control input label – equip the named theme, e.g. 'Equip Sunset'"),
            ]
            : [
                Text("\(activeGameTitle) Card", comment: "Voice Control input label – the active card in the game carousel, e.g. 'Crazy 8s Card'"),
                Text("Select Game", comment: "Voice Control input label – select the current game in the carousel"),
                Text("Current Game", comment: "Voice Control input label – refers to the game currently centered in the carousel"),
                Text("Select \(activeGameTitle)", comment: "Voice Control input label – select the named game, e.g. 'Select Crazy 8s'"),
                Text("Open submenu", comment: "Voice Control input label – open the submenu for the selected game"),
                Text("Open Game", comment: "Voice Control input label – open the selected game"),
                Text("Open \(activeGameTitle)", comment: "Voice Control input label – open the named game, e.g. 'Open Crazy 8s'"),
                Text("Play Game", comment: "Voice Control input label – play the selected game"),
                Text("Play \(activeGameTitle)", comment: "Voice Control input label – play the named game, e.g. 'Play Crazy 8s'"),
            ])
        .accessibilityValue(Text(verbatim: showingThemes ? activeThemeTitle : activeGameTitle))
        .accessibilityAddTraits(showingThemes ? [.isButton] : [])
        // The picker deliberately has no hint — its label, value and button trait already say
        // everything, and the old theme wheel shipped without one. An empty hint reads as no hint.
        .accessibilityHint(showingThemes
            ? Text(verbatim: "")
            : Text("Swipe up or down to change game. Double tap to open the \(activeGameTitle) menu.", comment: "VoiceOver accessibility hint for the game-selection carousel, %@ is the selected game name"))
        .accessibilityAction { // Default VoiceOver Activation Action
            if showingThemes {
                onThemeSelected(activeThemeIndex)
            } else {
                selectCentredGame()
            }
        }
        .accessibilityScrollAction { edge in // Voice Control: "Scroll Left / Scroll Right"
            if edge == .leading { moveWheel(by: -1) }
            else if edge == .trailing { moveWheel(by: 1) }
        }
        .accessibilityAdjustableAction { direction in  // VoiceOver: swipe up / swipe down on adjustable
            switch direction {
            case .increment: moveWheel(by: 1)
            case .decrement: moveWheel(by: -1)
            @unknown default: break
            }
        }
    }
}
