//
//  MainMenuView.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 12/3/25.
//

import SwiftUI
import Messages

struct MainMenuView: View {
    @Environment(\.colorScheme) var colorScheme //for light/dark theme detection
    //@Environment(\.locale) var locale //for language detection
    @Environment(\.accessibilityShowButtonShapes) private var showButtonShapes
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MenuViewModel
    private var isExpanded: Bool { viewModel.presentationStyle == .expanded }
    private var motionSpeed: Double { reduceMotion ? 0.66 : 1.0 } //animations should run at 2/3 speed when "Reduce Motion" is enabled
    
    var onStartGame: (GameType, Int) -> Void //triggers createGame in MessagesViewController
    
    @State private var handSize = 7 //full game is normally 10, but 7 is quicker and better suited for mobile
    @State private var cardsAnimatedAway = 0
    @State private var golfAnimationOrder: [Int] = [0, 1, 2, 3, 5].shuffled() + [4]
    @State private var hiddenAnimatedAwayCards = 0
    @State private var isPulsating = false //for the "state game" text
    @State private var isBubblePulsating = false //for the joker's reminder bubble
    @State private var jokerIsRed = Bool.random() //50/50 red/black flip, re-rolled when the deck resets
    @State private var card7Image: String = "7Spades"
    @State private var card10Image: String = "10Clubs"
    let suits = ["Hearts", "Diamonds", "Clubs", "Spades"]

    /// Joker shown when the deck animates away. Matched to the equipped theme's fronts the same
    /// way playing-card fronts are (e.g. `jokerRed` → `jokerRedEnchanted`), with a 50/50 red/black flip.
    private var jokerCardName: String {
        cardBackSelection.themedFrontName(for: jokerIsRed ? "jokerRed" : "jokerBlack")
    }
    
    @State private var titleTransitionEdge: Edge = .trailing
    @State private var themeTitleTransitionEdge: Edge = .trailing
    @State private var activeGameIndex: Int = 0
    @State private var activeThemeIndex: Int = MainMenuView.initialSelectedThemeIndex()
    @State private var selectedThemeIndex: Int = MainMenuView.initialSelectedThemeIndex()
    @StateObject private var cardBackSelection = CurrentTheme.shared
    @StateObject private var store = StoreManager.shared
    @State private var availableGames: [MenuGame] = [
        MenuGame(type: .ginRummy, title: "Gin Rummy"),
        MenuGame(type: .crazy8s, title: "Crazy 8s"),
        MenuGame(type: .golf, title: "Golf")
    ]
    private static var themes: [DeckTheme] { DeckTheme.available }
    private var themes: [DeckTheme] { DeckTheme.available }
    private var isThemeSelected: Bool { activeThemeIndex == selectedThemeIndex }
    private var isActiveThemeWinLocked: Bool {
        guard let required = themes[activeThemeIndex].requiredWins else { return false }
        return WinTracker.shared.totalWins < required
    }
    /// True while the theme picker is open and displaying the American Flag theme — drives the eagle flyover.
    private var isAmericaThemeActive: Bool {
        showingThemes && themes[activeThemeIndex].logoCard == "cardBackAmerica"
    }
    // Eagle flyover (American Flag theme) — a one-shot pass across the screen, not a fly-in-and-rest:
    // starts off-screen right, flies left, and exits off-screen left. It doesn't cross flat: a single
    // linear 0->1 progress drives `EagleGlide`, which drops it in a very shallow swoop — a little high
    // coming in, level with the title's band dead center, climbing again as it leaves. If the theme
    // changes mid-flight, the glide is left to keep running while opacity fades it out wherever it is.
    @State private var isEagleFlying = false
    @State private var eagleProgress: Double = 0
    @State private var eagleOpacity: Double = 1
    @State private var eagleFlightGeneration = 0 //bumped on each new flight so stale completion timers can no-op instead of clobbering a newer flight
    private let eagleFlightDuration: Double = 3.5

    /// True while the theme picker is open and displaying the Spiderweb theme — drives the spider drop.
    private var isSpiderThemeActive: Bool {
        showingThemes && themes[activeThemeIndex].logoCard == "cardBackWeb"
    }
    // Spider drop (Spiderweb theme) — a round trip rather than the eagle's one-way pass: the spider
    // descends upside down from off-screen top until it covers the 🕸️ that ends the theme's title, holds
    // for a beat, rights itself, then climbs back up and out. Unlike the eagle it rides *inside* the title
    // view, so it inherits that emoji's font and scaling and a trailing alignment parks it right on it.
    @State private var isSpiderDropping = false
    @State private var spiderOffsetY: CGFloat = 0
    @State private var spiderRotation: Double = 0
    @State private var spiderOpacity: Double = 1
    @State private var spiderDropGeneration = 0 //bumped on each new drop so stale completion timers can no-op instead of clobbering a newer drop
    @State private var spiderStartOffsetY: CGFloat = -500 //replaced once the title's on-screen position is measured
    private let spiderDescentDuration: Double = 1.5
    private let spiderHoldDuration: Double = 1.0
    private let spiderSpinDuration: Double = 0.6

    /// True while the theme picker is open and displaying the Koi theme — drives the koi's leap.
    private var isKoiThemeActive: Bool {
        showingThemes && themes[activeThemeIndex].logoCard == "cardBackKoi"
    }
    // Koi leap (Koi theme) — two halves of a single jump whose apex sits off the top of the screen: the
    // fish swims in level from the left edge, banks upward and leaps out over the top, then re-enters
    // the top further right nose-down, levels out as it hits the water again and swims off the right
    // edge. Like the eagle it rides below the title rather than inside it, so it has the full width of
    // the screen to cross. A single linear 0->1 progress drives both arcs; `KoiArc` turns that into a
    // position and a heading, so the fish always points the way it's travelling.
    @State private var isKoiLeaping = false
    @State private var koiProgress: Double = 0
    @State private var koiOpacity: Double = 1
    @State private var koiLeapGeneration = 0 //bumped on each new leap so stale completion timers can no-op instead of clobbering a newer leap
    @State private var koiExitOffsetY: CGFloat = -200 //replaced once the fish's on-screen position is measured
    private let koiLeapDuration: Double = 3.0

    /// True while the theme picker is open and displaying the Enchanted theme — drives the fox's shapeshifting.
    private var isEnchantedThemeActive: Bool {
        showingThemes && themes[activeThemeIndex].logoCard == "cardBackEnchanted"
    }
    // Fox shapeshift (Enchanted theme) — the only one of these that loops instead of playing once: the 🦊
    // ending the Enchanted title shrinks away and a different woodland animal grows back in its place, over
    // and over, for as long as the theme is showing. Every pass opens on the fox, runs the other animals in
    // a fresh random order, then comes back to the fox and reshuffles. Like the spider it rides inside the
    // title, so it inherits that emoji's font and scaling; unlike the spider it *replaces* the glyph rather
    // than covering it — the title is split around the fox, so there's nothing left underneath for a
    // narrower animal to leave peeking out.
    private static let enchantedFox = "🦊"
    private static let enchantedGlow = Color(red: 255/255, green: 209/255, blue: 89/255).opacity(0.8) //golden yellow; the Enchanted title glows this instead of the usual white
    @State private var enchantedShapes: [String] = MainMenuView.makeEnchantedShapeCycle()
    @State private var enchantedShapeIndex = 0
    @State private var enchantedShapeOpacity: Double = 1
    @State private var enchantedShapeScale: Double = 1
    @State private var enchantedShapeGeneration = 0 //bumped on each new cycle so stale completion timers can no-op instead of clobbering a newer cycle
    private let enchantedShapeHoldDuration: Double = 1.1
    private let enchantedShapeSwapDuration: Double = 0.35

    /// One full pass of the shapeshift: the fox first, then every other animal in a random order.
    private static func makeEnchantedShapeCycle() -> [String] {
        var animals = ["🦡", "🦌", "🐺", "🦫", "🦉", "🦆", "🐻", "🦝", "🐰", "🦨"]
        if #available(iOS 17.4, *) { animals.append("🫎") } //the moose glyph only ships from 17.4 on; older systems would draw a missing-glyph box instead
        return [enchantedFox] + animals.shuffled()
    }

    private static func initialSelectedThemeIndex() -> Int {
        let name = CurrentTheme.shared.selectedName
        return themes.firstIndex(where: { $0.logoCard == name })
            ?? themes.firstIndex(where: { $0.logoCard == CurrentTheme.defaultName })
            ?? 0
    }
    @State private var activeSubmenu: GameType? = nil
    private var isInSubmenu: Bool { activeSubmenu != nil }
    @State private var isTitleBarHidden: Bool = false
    @State private var isCardWheelHidden: Bool = false
    @State private var showingRules: Bool = false
    @State private var showingThemes: Bool = false
    @State private var showingRestore: Bool = false
    @State private var isRestoring: Bool = false
    @State private var lastWinsShown: Int = 0 //tracks prior win count so numericText knows which direction to slide
    @AppStorage("hasCompletedMainMenuOnboarding") private var hasCompletedOnboarding: Bool = false
    @State private var hasDraggedCards: Bool = false //session-only flag; flips on first wheel movement to advance the onboarding subtitle
    @ScaledMetric(relativeTo: .title) private var scaledButtonUnit: CGFloat = 10
    private var buttonSize: CGFloat { isExpanded ? scaledButtonUnit * 7 : scaledButtonUnit * 4 }
    let isIpad = UIDevice.current.userInterfaceIdiom == .pad
  
    // MARK: - Top Level Parent View
    var body: some View {
        ZStack {
            switch activeSubmenu {
            case .ginRummy:
                ginSubmenuView
            case .crazy8s:
                crazy8sSubmenuView
            case .golf:
                golfSubmenuView
            default:
                EmptyView()
            }

            VStack {// Main view
                topSection
                    .accessibilityRepresentation {
                        if !isInSubmenu {
                            topSection
                        } else {
                            EmptyView()
                        }
                    }

                midSection
                    .accessibilityRepresentation {
                        if !isInSubmenu {
                            midSection
                        } else {
                            EmptyView()
                        }
                    }

                bottomSection
                    .accessibilityRepresentation {
                        if !isInSubmenu {
                            bottomSection
                        } else {
                            EmptyView()
                        }
                    }
            }
        }
        .accessibilityHidden(showingRules)
        .overlay {
            if showingRules {
                RulesView(gameType: availableGames[activeGameIndex].type, showsGinKnockRules: viewModel.is1v1, isExpanded: isExpanded) {
                    withAnimation(.easeInOut(duration: 0.2).speed(motionSpeed)) {
                        showingRules = false
                    }
                }
                .transition(.opacity)
            }
        }
        .background(FeltBackgroundView())
        .onAppear {
            preloadWins()
            preloadThemeArtwork()
        }
        .task {
            await store.start()
        }
        .accessibilityAction(.escape) {
            if showingThemes { // Closes the themes menu
                withAnimation(.spring(response: 1, dampingFraction: 0.7).speed(motionSpeed)) {
                    showingThemes = false
                    activeThemeIndex = selectedThemeIndex
                }
            } else if showingRules { // Closes the rules view
                withAnimation(.easeInOut(duration: 0.4).speed(motionSpeed)) {
                    showingRules = false
                }
            } else if isInSubmenu { // Exits the active game submenu
                withAnimation(.default.speed(motionSpeed)) {
                    activeSubmenu = nil
                }
            } else { // Nothing is open to close, so let the system dismiss the whole view
                dismiss()
            }
        }
    }
    
    
    // MARK: - Top Section
    private var topSection: some View {
        VStack(spacing: isExpanded ? 15 : (showButtonShapes ? 0 : 5)) {
            
            mainTitle
                .accessibilityRepresentation {
                    //if !isInSubmenu {
                        if showingThemes {
                            themeTitleFace
                        } else {
                            gameTitleFace
                        }
                    //} else {
                    //    EmptyView()
                    //}
                }

            mainSubtitle
                .accessibilityRepresentation {
                    //if !isInSubmenu {
                        if showingThemes {
                            priceFace
                        } else {
                            winCounterFace
                        }
                    //} else {
                    //    EmptyView()
                    //}
                }
    
            Divider()
                .opacity(0)
            
            Divider() //a teensy bit silly
                .opacity(0)
            
        }
        .scaleEffect(isExpanded ? 1.2 : 1)
        .background( //the gradient at the top of the screen
            Rectangle()
                .fill(.ultraThinMaterial)
                .mask(
                    LinearGradient(
                        colors: [.black, .clear], //color doesnt matter here, only opacity
                        startPoint: .top,
                        endPoint: .bottom //UnitPoint(x: 0.5, y: 0.75) //<- alternative for shorter gradient
                    )
                )
                .ignoresSafeArea()
        )
        .opacity(isTitleBarHidden ? 0 : 1)
        .accessibilityHidden(isTitleBarHidden)
    }
    
    private var mainTitle: some View {
        ZStack {
            gameTitleFace

            themeTitleFace
        }
        .padding(.top, isExpanded ? (isIpad ? 30 : 15) : 0) //pretty sure spacing doesnt include safearea - first element
        .scaleEffect(isExpanded ? 1.2 : 1)
        .rotation3DEffect(.degrees(showingThemes ? -180 : 0), axis: (x: 0, y: 1, z: 0))
        //eagleOverlay is attached after the 3D flip so it never rotates with the title, and as an
        //overlay it takes up no layout space of its own — it can't push the title/price apart.
        //offset drops it below the title's bottom edge, into the gap before the price text.
        .overlay(eagleOverlay.offset(y: isExpanded ? 36 : 18), alignment: .bottom)
        //koiOverlay rides in the same band as the eagle, and for the same reasons — outside the 3D flip
        //so it never rotates with the title, and as an overlay so it can leave the title's bounds freely.
        .overlay(koiOverlay.offset(y: isExpanded ? 36 : 18), alignment: .bottom)
        .onChange(of: isAmericaThemeActive) { _, isActive in
            if isActive {
                startEagleFlight()
            } else {
                stopEagleFlightAndFade()
            }
        }
        .onChange(of: isSpiderThemeActive) { _, isActive in
            if isActive {
                startSpiderDrop()
            } else {
                stopSpiderDropAndFade()
            }
        }
        .onChange(of: isKoiThemeActive) { _, isActive in
            if isActive {
                startKoiLeap()
            } else {
                stopKoiLeapAndFade()
            }
        }
        .onChange(of: isEnchantedThemeActive) { _, isActive in
            if isActive {
                startEnchantedShapeshift()
            } else {
                stopEnchantedShapeshift()
            }
        }
    }
    
    private var gameTitleFace: some View {
        Text(verbatim: availableGames[activeGameIndex].displayTitle)
            .font(.largeTitle)
            .fontWeight(.semibold)
            .fontDesign(.serif)
            .foregroundColor(.white)
            .shadow(color: .white.opacity(0.33), radius: 5)
            .id(activeGameIndex)
            .transition(.asymmetric(
                insertion: .move(edge: titleTransitionEdge).combined(with: .opacity),
                removal: .move(edge: titleTransitionEdge == .trailing ? .leading : .trailing).combined(with: .opacity)
            ))
            .animation(.easeInOut.speed(motionSpeed), value: activeGameIndex)
            .modifier(FlipOpacity(rotation: showingThemes ? 180 : 0))
            .accessibilityLabel(Text("Selected game: \(availableGames[activeGameIndex].displayTitle)", comment: "VoiceOver accessibility label that announces the currently selected game, e.g. 'Selected game: Crazy 8s'"))
            .accessibilityHidden(showingThemes)
    }

    /// The Enchanted title's localized text split around its 🦊, or nil for every other theme — and for any
    /// translation that has lost the fox, which then renders as an ordinary one-piece title.
    private var enchantedTitleParts: (before: String, after: String)? {
        guard themes[activeThemeIndex].logoCard == "cardBackEnchanted" else { return nil }
        let title = String(localized: String.LocalizationValue(themes[activeThemeIndex].title))
        guard let fox = title.range(of: Self.enchantedFox) else { return nil }
        return (String(title[..<fox.lowerBound]), String(title[fox.upperBound...]))
    }

    /// The active theme's name: one plain localized Text, except for Enchanted, whose fox is lifted out into
    /// its own view so it can be swapped for the other woodland animals.
    @ViewBuilder
    private var themeTitleText: some View {
        if let parts = enchantedTitleParts {
            HStack(spacing: 0) {
                Text(verbatim: parts.before)
                enchantedShapeView
                Text(verbatim: parts.after)
            }
        } else {
            Text(LocalizedStringKey(themes[activeThemeIndex].title))
        }
    }

    /// The glow behind the theme's name. Enchanted glows gold — words and shapeshifting animal alike, since
    /// this is one shadow over the whole title; every other theme keeps the menu's usual faint white.
    private var themeTitleGlow: Color {
        themes[activeThemeIndex].logoCard == "cardBackEnchanted" ? Self.enchantedGlow : .white.opacity(0.33)
    }

    private var themeTitleFace: some View {
        themeTitleText
            //Attached before .font so the spider inherits it, and before the 3D flip below so the flip's
            //180° cancels the parent's -180° for the spider exactly as it does for the title text.
            .overlay(alignment: .trailing) { spiderOverlay }
            .font(.largeTitle)
            .fontWeight(.semibold)
            .fontDesign(.serif)
            .foregroundColor(.white)
            .shadow(color: themeTitleGlow, radius: 5)
            .id(activeThemeIndex)
            .transition(.asymmetric(
                insertion: .move(edge: themeTitleTransitionEdge).combined(with: .opacity),
                removal: .move(edge: themeTitleTransitionEdge == .trailing ? .leading : .trailing).combined(with: .opacity)
            ))
            .animation(.easeInOut.speed(motionSpeed), value: activeThemeIndex)
            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            .modifier(FlipOpacity(rotation: showingThemes ? 0 : 180))
            .accessibilityLabel(Text("Selected theme: \(themes[activeThemeIndex].title)", comment: "VoiceOver accessibility label that announces the currently selected card-back theme, e.g. 'Selected theme: Sunset'"))
            .accessibilityHidden(!showingThemes)
    }

    /// Eagle emoji that flies across the screen (right to left) while the American Flag theme is showing.
    private var eagleOverlay: some View {
        Text("🦅")
            .font(.system(size: isExpanded ? 40 : 30))
            //.shadow(color: .black.opacity(0.25), radius: 5)
            .modifier(EagleGlide(progress: eagleProgress, screenWidth: UIScreen.main.bounds.width))
            .opacity(isEagleFlying ? eagleOpacity : 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func startEagleFlight() {
        eagleFlightGeneration += 1
        let generation = eagleFlightGeneration //stamps this flight so stale timers below can recognize they've been superseded

        //A plain assignment isn't enough to guarantee an instant snap: if the previous flight's linear
        //animation is still interpolating eagleProgress when this runs, SwiftUI retargets that animation
        //in place rather than cutting it off, so the new glide starts blended with the old one's leftover
        //momentum (fast, then settling into the real speed). Disabling animations for the reset forces a
        //hard, non-interpolated snap so every restart begins from a clean, motionless state.
        var resetTransaction = Transaction()
        resetTransaction.disablesAnimations = true
        withTransaction(resetTransaction) {
            eagleProgress = 0 //snap back off-screen right, at the high end of the swoop
            eagleOpacity = 1
            isEagleFlying = true
        }

        //Linear on purpose: the crossing holds one steady speed the whole way, and the swoop is shaped
        //inside EagleGlide rather than by easing this — easing here would slow the horizontal pass too.
        withAnimation(.linear(duration: eagleFlightDuration).speed(motionSpeed)) {
            eagleProgress = 1 //glide off-screen left
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + eagleFlightDuration / motionSpeed) {
            guard generation == eagleFlightGeneration else { return } //a newer flight has since started — leave its state alone
            isEagleFlying = false //flight finished naturally; reset for next time
        }
    }

    private func stopEagleFlightAndFade() {
        guard isEagleFlying else { return }
        let generation = eagleFlightGeneration //the flight being stopped, not a new one — stopping never starts a fresh generation
        //leave eagleProgress's animation running so the eagle keeps drifting while it fades, rather than
        //snapping to a stop — it just fades out wherever that motion happens to be.
        withAnimation(.easeOut(duration: 0.3).speed(motionSpeed)) {
            eagleOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 / motionSpeed) {
            guard generation == eagleFlightGeneration else { return } //a new flight started before this fade finished
            isEagleFlying = false
        }
    }

    /// Spider that lowers onto the 🕸️ ending the Spiderweb title. It deliberately sets no font of its
    /// own: attached inside the title, it inherits the title's, so it renders at the same size as that web
    /// emoji and trailing-aligns onto exactly the glyph it's aiming for — in any language, at any Dynamic
    /// Type size, and through the title's scaleEffects — without any of it having to be measured.
    private var spiderOverlay: some View {
        Text("🕷️")
            .background( //measures how far up the spider must travel to clear the top of the screen
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { updateSpiderStartOffset(from: proxy.frame(in: .global)) }
                        .onChange(of: proxy.frame(in: .global)) { _, frame in
                            updateSpiderStartOffset(from: frame)
                        }
                }
            )
            .rotationEffect(.degrees(spiderRotation))
            .offset(y: spiderOffsetY)
            .opacity(isSpiderDropping ? spiderOpacity : 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// Where the spider parks when off-screen, as an offset from the web it hangs above. `frame` is the
    /// spider's *layout* position, which ignores the title's scaleEffects — under those this offset renders
    /// larger than it's computed here, which only ever carries the spider further off-screen.
    private func updateSpiderStartOffset(from frame: CGRect) {
        guard frame.height > 0 else { return } //nothing laid out yet — keep the placeholder
        spiderStartOffsetY = -(frame.maxY + frame.height)
    }

    private func startSpiderDrop() {
        spiderDropGeneration += 1
        let generation = spiderDropGeneration //stamps this drop so stale timers below can recognize they've been superseded

        //Same reasoning as the eagle's reset: a plain assignment would retarget a still-running animation
        //rather than cut it off, so a restarted drop would inherit the previous one's leftover momentum.
        var resetTransaction = Transaction()
        resetTransaction.disablesAnimations = true
        withTransaction(resetTransaction) {
            spiderOffsetY = spiderStartOffsetY //snap off-screen top
            spiderRotation = 180 //comes down upside down, as if lowering head-first on a thread
            spiderOpacity = 1
            isSpiderDropping = true
        }

        withAnimation(.easeInOut(duration: spiderDescentDuration).speed(motionSpeed)) {
            spiderOffsetY = 0 //trailing alignment already sits it on the web, so zero offset covers the emoji outright
        }

        let spinDelay = (spiderDescentDuration + spiderHoldDuration) / motionSpeed //descend, then hold on the web for a beat
        DispatchQueue.main.asyncAfter(deadline: .now() + spinDelay) {
            guard generation == spiderDropGeneration, isSpiderDropping else { return } //a newer drop (or a fade-out) has since taken over
            withAnimation(.easeInOut(duration: spiderSpinDuration).speed(motionSpeed)) {
                spiderRotation = 360 //turns upright in place, ready to climb back the way it came — 360 rather than 0 so the half turn runs clockwise
            }
        }

        let climbDelay = spinDelay + spiderSpinDuration / motionSpeed
        DispatchQueue.main.asyncAfter(deadline: .now() + climbDelay) {
            guard generation == spiderDropGeneration, isSpiderDropping else { return }
            withAnimation(.easeIn(duration: spiderDescentDuration).speed(motionSpeed)) {
                spiderOffsetY = spiderStartOffsetY //back up and off the top of the screen
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + climbDelay + spiderDescentDuration / motionSpeed) {
            guard generation == spiderDropGeneration else { return }
            isSpiderDropping = false //round trip finished naturally; reset for next time
        }
    }

    private func stopSpiderDropAndFade() {
        guard isSpiderDropping else { return }
        let generation = spiderDropGeneration //the drop being stopped, not a new one — stopping never starts a fresh generation
        //leave spiderOffsetY's animation running so the spider keeps moving while it fades, rather than
        //snapping to a stop — it just fades out wherever that motion happens to be.
        withAnimation(.easeOut(duration: 0.3).speed(motionSpeed)) {
            spiderOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 / motionSpeed) {
            guard generation == spiderDropGeneration else { return } //a new drop started before this fade finished
            isSpiderDropping = false
        }
    }

    /// Koi that leaps over the top of the screen while the Koi theme is showing.
    private var koiOverlay: some View {
        Text("🐟")
            .font(.system(size: isExpanded ? 40 : 30))
            .background( //measures how far up the fish must travel to clear the top of the screen
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { updateKoiExitOffset(from: proxy.frame(in: .global)) }
                        .onChange(of: proxy.frame(in: .global)) { _, frame in
                            updateKoiExitOffset(from: frame)
                        }
                }
            )
            //🐟 is drawn facing left and the whole leap travels right, so it's mirrored once here,
            //underneath KoiArc, leaving that free to rotate it into the direction of travel as normal.
            .scaleEffect(x: -1)
            .modifier(KoiArc(progress: koiProgress,
                             screenWidth: UIScreen.main.bounds.width,
                             exitY: koiExitOffsetY))
            .opacity(isKoiLeaping ? koiOpacity : 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// How far above the waterline the koi has to be to clear the top of the screen, as an offset from
    /// where it rests. Measured like the spider's: `frame` is the fish's *layout* position, so it ignores
    /// the title's scaleEffects — under those this offset renders larger than it's computed here, which
    /// only ever carries the fish further off-screen.
    private func updateKoiExitOffset(from frame: CGRect) {
        guard frame.height > 0 else { return } //nothing laid out yet — keep the placeholder
        koiExitOffsetY = -(frame.maxY + frame.height)
    }

    private func startKoiLeap() {
        koiLeapGeneration += 1
        let generation = koiLeapGeneration //stamps this leap so stale timers below can recognize they've been superseded

        //Same reasoning as the eagle's reset: a plain assignment would retarget a still-running animation
        //rather than cut it off, so a restarted leap would inherit the previous one's leftover momentum.
        var resetTransaction = Transaction()
        resetTransaction.disablesAnimations = true
        withTransaction(resetTransaction) {
            koiProgress = 0 //snap back off-screen left, at the waterline
            koiOpacity = 1
            isKoiLeaping = true
        }

        //Linear on purpose: the burst out of the water and the fall back into it are eased separately
        //inside KoiArc, which one curve spanning both of them couldn't express.
        withAnimation(.linear(duration: koiLeapDuration).speed(motionSpeed)) {
            koiProgress = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + koiLeapDuration / motionSpeed) {
            guard generation == koiLeapGeneration else { return } //a newer leap has since started — leave its state alone
            isKoiLeaping = false //leap finished naturally; reset for next time
        }
    }

    private func stopKoiLeapAndFade() {
        guard isKoiLeaping else { return }
        let generation = koiLeapGeneration //the leap being stopped, not a new one — stopping never starts a fresh generation
        //leave koiProgress's animation running so the fish keeps swimming while it fades, rather than
        //snapping to a stop — it just fades out wherever that motion happens to be.
        withAnimation(.easeOut(duration: 0.3).speed(motionSpeed)) {
            koiOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 / motionSpeed) {
            guard generation == koiLeapGeneration else { return } //a new leap started before this fade finished
            isKoiLeaping = false
        }
    }

    /// The animal currently standing in for the Enchanted theme's fox.
    private var enchantedShape: String {
        enchantedShapes.indices.contains(enchantedShapeIndex) ? enchantedShapes[enchantedShapeIndex] : Self.enchantedFox
    }

    /// The shapeshifting animal spliced into the Enchanted title in place of its 🦊. Like the spider it
    /// deliberately sets no font of its own: sitting inside the title, it inherits the title's, so it renders
    /// at exactly the size — in any language, at any Dynamic Type size, through the title's scaleEffects —
    /// that the fox it replaced would have.
    private var enchantedShapeView: some View {
        Text(verbatim: enchantedShape)
            .scaleEffect(enchantedShapeScale)
            .opacity(enchantedShapeOpacity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func startEnchantedShapeshift() {
        enchantedShapeGeneration += 1
        let generation = enchantedShapeGeneration //stamps this cycle so stale timers below can recognize they've been superseded

        //Same reasoning as the eagle's reset: a plain assignment would retarget a still-running animation
        //rather than cut it off, so a restarted cycle would open blended with the previous one's leftover fade.
        var resetTransaction = Transaction()
        resetTransaction.disablesAnimations = true
        withTransaction(resetTransaction) {
            enchantedShapes = Self.makeEnchantedShapeCycle()
            enchantedShapeIndex = 0 //the fox always leads
            enchantedShapeOpacity = 1
            enchantedShapeScale = 1
        }
        scheduleEnchantedShapeSwap(generation: generation)
    }

    /// Holds the animal on screen for a beat, shrinks it away, swaps the next one in behind the cover of
    /// that gap and grows it back — then queues itself again, so the cycle runs until the theme changes.
    private func scheduleEnchantedShapeSwap(generation: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + enchantedShapeHoldDuration / motionSpeed) {
            guard generation == enchantedShapeGeneration else { return } //a newer cycle (or a stop) has since taken over
            withAnimation(.easeIn(duration: enchantedShapeSwapDuration).speed(motionSpeed)) {
                enchantedShapeOpacity = 0
                enchantedShapeScale = 0.6 //shrinks out rather than simply fading, so the swap reads as the animal transforming
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + enchantedShapeSwapDuration / motionSpeed) {
                guard generation == enchantedShapeGeneration else { return }
                advanceEnchantedShape() //swapped while it's invisible, so the two animals are never on screen together
                withAnimation(.easeOut(duration: enchantedShapeSwapDuration).speed(motionSpeed)) {
                    enchantedShapeOpacity = 1
                    enchantedShapeScale = 1
                }
                scheduleEnchantedShapeSwap(generation: generation)
            }
        }
    }

    /// Steps to the next animal, reshuffling as the fox comes back around so no two passes run the same order.
    private func advanceEnchantedShape() {
        let next = enchantedShapeIndex + 1
        if next < enchantedShapes.count {
            enchantedShapeIndex = next
        } else {
            enchantedShapes = Self.makeEnchantedShapeCycle()
            enchantedShapeIndex = 0
        }
    }

    /// Stops the cycle wherever it stands. Nothing is reset here — the title is already animating away, and
    /// ``startEnchantedShapeshift()`` puts the fox back before the next one arrives.
    private func stopEnchantedShapeshift() {
        enchantedShapeGeneration += 1
    }
    

    private var mainSubtitle: some View {
        ZStack {
            winCounterFace

            priceFace
        }
        .font(isExpanded ? .headline : .subheadline)
        .fontWeight(.medium)
        .padding(.top, isExpanded ? 15 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7).speed(motionSpeed), value: isExpanded)
        .scaleEffect(isExpanded ? 1.2 : 1)
        .rotation3DEffect(.degrees(showingThemes ? -180 : 0), axis: (x: 0, y: 1, z: 0))
    }
    
    private var winCounterFace: some View {
        ZStack {
            if hasCompletedOnboarding {
                winCountContent
                    .transition(.opacity)
            } else {
                onboardingSubtitle
                    .transition(.opacity)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .modifier(FlipOpacity(rotation: showingThemes ? 180 : 0))
        .accessibilityHidden(showingThemes)
    }

    private var winCountContent: some View {
        HStack(spacing: 4) { // Adjust spacing to move the crown closer/further from the text
            Image(systemName: "crown.fill")
                .foregroundStyle(LinearGradient(colors: [
                    Color(red: 1.0, green: 1.0, blue: 0.33), // Bright Yellow at the top
                    Color(red: 1.0, green: 0.7, blue: 0.3) // Orangish gold at the bottom
                ],
                startPoint: .top, // or topLeading
                endPoint: .bottom // & bottomTrailing
                ))
                .shadow(color: .orange, radius: 5)

            Text("\(availableGames[activeGameIndex].wins) Wins")
                .foregroundColor(.white)
                .shadow(color: .white.opacity(0.33), radius: 5)
                .contentTransition(.numericText(countsDown: availableGames[activeGameIndex].wins < lastWinsShown))
                .animation(.snappy.speed(motionSpeed), value: availableGames[activeGameIndex].wins)
                .onChange(of: availableGames[activeGameIndex].wins) { _, newValue in
                    lastWinsShown = newValue
                }
        }
        .accessibilityElement(children: .ignore) //dont count the crown as a seperate element
        .accessibilityLabel(Text("\(availableGames[activeGameIndex].displayTitle) win count: \(availableGames[activeGameIndex].wins)", comment: "VoiceOver accessibility label that announces the win count for a specific game, e.g. 'Crazy 8s win count: 5'"))
    }

    private var onboardingSubtitle: some View {
        Text(hasDraggedCards ? "Tap a card to select a game" : "Drag the cards left or right")
            .foregroundColor(.white)
            .shadow(color: .white.opacity(0.33), radius: 5)
            .id(hasDraggedCards ? "onboarding.tap" : "onboarding.drag") //distinct id so SwiftUI animates the swap
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            ))
            .accessibilityLabel(hasDraggedCards
                ? Text("Tap a card to select a game", comment: "VoiceOver accessibility label – onboarding hint shown after the user has dragged cards")
                : Text("Drag the cards left or right", comment: "VoiceOver accessibility label – initial onboarding hint to drag the card carousel"))
    }
    
    private var priceFace: some View {
        priceText
            .foregroundColor(.white)
            .shadow(color: .white.opacity(0.33), radius: 5)
            .fixedSize(horizontal: true, vertical: false)
            .id(priceTextKey) //distinct labels get distinct identities so the slide only fires when the displayed text actually changes
            .transition(.asymmetric(
                insertion: .move(edge: themeTitleTransitionEdge).combined(with: .opacity),
                removal: .move(edge: themeTitleTransitionEdge == .trailing ? .leading : .trailing).combined(with: .opacity)
            ))
            .animation(.easeInOut.speed(motionSpeed), value: activeThemeIndex) //animates only on theme swipes — internal state toggles snap
            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            .modifier(FlipOpacity(rotation: showingThemes ? 0 : 180))
            .accessibilityHidden(!showingThemes)
            /*.accessibilityRepresentation {
                if showingThemes {
                    priceText // Feed VoiceOver the buttons only when the menu is actually open
                } else {
                    EmptyView() // Feed VoiceOver nothing. It cannot read what isn't there.
                }
            }*/
    }
    
    
    // MARK: - Mid Section
    private var midSection: some View {
        Spacer()
            .frame(maxWidth: .infinity)
            .overlay(alignment: .leading) {
                rulesButton
                    .padding(.leading, isExpanded ? (isIpad ? 270 : 75) : (showButtonShapes ? 10 : 25))
                    .padding(.top, isExpanded ? (isIpad ? -120 : -130) : (showButtonShapes ? 20 : 0))
                    .opacity(isTitleBarHidden ? 0 : 1)
                    .accessibilityHidden(isTitleBarHidden)
            }
            .overlay(alignment: .trailing) {
                customizationButton
                    .padding(.trailing, isExpanded ? (isIpad ? 270 : 75) : (showButtonShapes ? 10 : 25))
                    .padding(.top, isExpanded ? (isIpad ? 70 : 100) : (showButtonShapes ? 20 : 0))
                    .opacity(isTitleBarHidden ? 0 : 1)
                    .accessibilityHidden(isTitleBarHidden)
            }
    }
    
    private var rulesButton: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            if showingThemes {
                withAnimation(.spring(response: 1, dampingFraction: 0.7).speed(motionSpeed)) {
                    showingThemes = false
                    activeThemeIndex = selectedThemeIndex
                }
            } else {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7).speed(motionSpeed)) {
                    showingRules = true
                }
            }
        }) {
            HStack { // Groups the icon and text
                let currentIcon = showingThemes ? Image(systemName: "chevron.left") : Image("colored.text.book.closed")
                let iconRenderSize = scaledButtonUnit * 7 // fixed render size; scaleEffect handles compact/expanded sizing
                currentIcon
                    .font(.system(size: iconRenderSize, weight: showingThemes ? .medium : .regular))
                    .frame(width: iconRenderSize, height: iconRenderSize)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(
                        .white,            // Primary (Layer 1)
                        Color(white: 0.3), // Secondary (Layer 2)
                        Color.bookBrown // Tertiary (Layer 3)
                    )
                    .contentTransition(.symbolEffect(.replace))
                    .applyGradientSymbolColor()
                    .shadow(color: .black.opacity(0.15), radius: 5, x: -5, y: 5)
                    .scaleEffect(buttonSize / iconRenderSize)
                    .frame(width: buttonSize, height: buttonSize)

                ZStack(alignment: .leading) {
                    if showingThemes {
                        Text("Back")
                            .font(isExpanded ? (isIpad ? .title2 : .title) : .headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .transition(
                                // Slides in from the right while fading
                                .move(edge: .trailing)
                                .combined(with: .opacity)
                            )
                    } else {
                        Text("Rules")
                            .font(isExpanded ? (isIpad ? .title2 : .title) : .headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .transition(
                                // Slides out to the left and shrinks
                                .move(edge: .leading)
                                .combined(with: .opacity)
                                .combined(with: .scale(scale: 0.5, anchor: .leading))
                            )
                    }
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding(showButtonShapes ? (isExpanded ? EdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20) : EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16)) : EdgeInsets())
            .background(
                Group {
                    if showButtonShapes {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                }
            )
        }
        .buttonStyle(.plain) //turns off the accessibility background showing the button shape we do this manually
        .accessibilityLabel(showingThemes
            ? Text("Back", comment: "VoiceOver accessibility label – back button to leave themes mode")
            : Text("Rules", comment: "VoiceOver accessibility label – opens the rules of the selected game"))
        .accessibilityAddTraits(.isButton)
    }
    
    private var customizationButton: some View {
        Button(action: {
            if !showingThemes { // Opening the themes menu
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                activeThemeIndex = selectedThemeIndex
                withAnimation(.spring(response: 1, dampingFraction: 0.7).speed(motionSpeed)) {
                    showingThemes = true
                }
                
            } else { // In themes mode: equip the active theme (handles win-lock, ownership, purchase, and already-selected)
                selectTheme(at: activeThemeIndex)
            }
        }) {
            HStack(spacing: 16) {
                ZStack(alignment: .leading) {
                    if !showingThemes {
                        Text("Themes")
                            .font(isExpanded ? (isIpad ? .title2 : .title) : .headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .transition(
                                // Slides out from the left while fading
                                .move(edge: .leading)
                                .combined(with: .opacity)
                                .combined(with: .scale(scale: 0.5, anchor: .leading))
                            )
                    } else {
                        Text("Select")
                            .font(isExpanded ? (isIpad ? .title2 : .title) : .headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .transition(
                                // Slides out from the left while fading
                                .move(edge: .trailing)
                                .combined(with: .opacity)
                            )
                    }
                }
                
                
                let iconRenderSize = scaledButtonUnit * 7 // fixed render size; scaleEffect handles compact/expanded sizing
                Image(systemName: showingThemes ? "checkmark.circle.fill" : "paintpalette.fill")
                    .font(.system(size: iconRenderSize, weight: showingThemes ? .semibold : .regular))
                    .frame(width: iconRenderSize, height: iconRenderSize)
                    .symbolRenderingMode(.multicolor)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: selectedThemeIndex)
                    .applyGradientSymbolColor()
                    .saturation(showingThemes && (isThemeSelected || isActiveThemeWinLocked) ? 0 : 1)
                    .shadow(color: .black.opacity(0.15), radius: 5, x: 5, y: 5)
                    .scaleEffect(buttonSize / iconRenderSize)
                    .frame(width: buttonSize, height: buttonSize)
                
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding(showButtonShapes ? (isExpanded ? EdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20) : EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16)) : EdgeInsets())
            .background(
                Group {
                    if showButtonShapes {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                }
            )
        }
        .buttonStyle(.plain) //turns off the accessibility background showing the button shape
        .accessibilityLabel(showingThemes
            ? Text("Select", comment: "VoiceOver accessibility label – confirm the highlighted theme selection")
            : Text("Themes", comment: "VoiceOver accessibility label – opens the theme picker"))
        .accessibilityAddTraits(.isButton)
    }
    
    
    // MARK: - Bottom Section
    private var bottomSection: some View {
        // One hand of cards, serving both carousels. Opening the theme picker turns it over in
        // place; it is never swapped for, or stacked on top of, a second set of cards.
        menuCardWheel
        //.zIndex(999) //keep the cards on top
        .frame(maxWidth: UIScreen.main.bounds.width) //dont let the cards expand the zstack when they fan out
        .scaleEffect(isExpanded ? 1.4 : 1.1)
        .offset(y: isExpanded ? (isInSubmenu ? -175 : 5) : 40) //40: in compact main menu
        .opacity(isCardWheelHidden ? 0 : 1)
        .accessibilityHidden(isCardWheelHidden)
    }

    private var menuCardWheel: some View {
        MenuCardWheel(
            games: availableGames,
            themes: themes,
            showingThemes: showingThemes,
            selectedThemeIndex: selectedThemeIndex,
            onActiveGameChange: { newIndex, direction in // handle real-time mid-swipe updates
                if activeGameIndex != newIndex {
                    titleTransitionEdge = direction
                    withAnimation(.easeInOut(duration: 0.2).speed(motionSpeed)) {
                        activeGameIndex = newIndex
                    }
                    if !hasCompletedOnboarding && !hasDraggedCards {
                        withAnimation(.easeInOut(duration: 0.4).speed(motionSpeed)) {
                            hasDraggedCards = true
                        }
                    }
                }
            },
            onActiveThemeChange: { newIndex, direction in
                if activeThemeIndex != newIndex {
                    themeTitleTransitionEdge = (direction == .trailing) ? .leading : .trailing
                    withAnimation(.easeInOut(duration: 0.2).speed(motionSpeed)) {
                        activeThemeIndex = newIndex
                    }
                }
            },
            userSelectedGame: { index in // handle selecting a game
                // Must match `MenuCardWheel.selectionAnimation`. `hasSelectedGame` is
                // `activeSubmenu != nil`, so its binding has *already* set this in the same update,
                // inside the wheel's selection spring — this write only re-asserts it against the
                // wheel's own index. Two writes to one piece of state in one update means whichever
                // transaction the subtree ends up carrying decides how fast the hand lifts, and an
                // in-flight settle spring is enough to change which one that is. With a shorter
                // animation here the hand rose in 0.2s after a flick and 0.6s from rest, so the
                // fixed delay on the title-bar fade below (tuned for the slow case) left the menu
                // elements still on screen after the cards had swiped past them. Same animation
                // both sides, one speed either way.
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7).speed(motionSpeed)) {
                    activeSubmenu = availableGames[index].type
                }
                withAnimation(.linear(duration: 0.05).delay(0.12).speed(motionSpeed)) { //wait a bit then trigger a fast fade
                    isTitleBarHidden = true
                    if !hasCompletedOnboarding {
                        hasCompletedOnboarding = true
                    }
                }
                let speed = motionSpeed
                Task {
                    try? await Task.sleep(nanoseconds: UInt64(300_000_000.0 / speed)) // 0.3 seconds (scaled for reduce motion)
                    isCardWheelHidden = true //hide AFTER the animation to render the cards invisible so they dont clip in when transitioning between compact and expanded in the subview
                }
            },
            onThemeSelected: { selectedIndex in
                // Routes through the same endpoint as the Select button so tapping a card
                // can't bypass the win-lock / ownership / purchase checks.
                selectTheme(at: selectedIndex)
            },
            hasSelectedGame: Binding(
                get: { activeSubmenu != nil },
                set: { newValue in
                    if newValue {
                        activeSubmenu = availableGames[activeGameIndex].type
                    } else {
                        activeSubmenu = nil
                    }
                }
            )
        )
    }

    
    // MARK: - Menu helper functions

    /// Warms the asset cache for the theme picker's card backs.
    ///
    /// A card in the hand only builds its theme artwork once it has turned past edge-on, which is
    /// what keeps the picker's images out of memory until they're wanted — but it would otherwise
    /// put every first-time decode on the main thread at the exact midpoint of the flip, which is
    /// the one frame that can least afford it. Touching them once when the menu appears makes that
    /// midpoint a cache hit instead.
    private func preloadThemeArtwork() {
        let names = themes.map(\.logoCard)
        Task.detached(priority: .utility) {
            for name in names { _ = UIImage(named: name) }
        }
    }

    private func preloadWins() {
        for index in availableGames.indices {
            let title = availableGames[index].title
            availableGames[index].wins = WinTracker.shared.getWinCount(for: title)
        }
    }

    //distills the priceText into a stable key — identical labels (e.g. two Owned themes) share an id so no slide fires
    private var priceTextKey: String {
        let theme = themes[activeThemeIndex]
        guard let productID = theme.productID else { return "owned" }
        if store.isOwned(productID) { return "owned" }
        if let required = theme.requiredWins, WinTracker.shared.totalWins < required {
            return "winlock:\(required)"
        }
        if isRestoring { return "restoring" }
        if showingRestore { return "restore" }
        if let price = store.displayPrice(for: productID) { return "price:\(price)" }
        return "loading"
    }

    /// Single entry point for equipping a theme, shared by the Select button, tapping the
    /// center card, and VoiceOver activation. Enforces win-locks and IAP ownership before
    /// committing, and kicks off a purchase when the theme is paid and not yet owned.
    private func selectTheme(at index: Int) {
        let theme = themes[index]

        // Win-locked: reject with an error haptic.
        if let required = theme.requiredWins, WinTracker.shared.totalWins < required {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }

        // Already the equipped theme: nothing to do.
        if index == selectedThemeIndex {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }

        // Owned (or free — nil productID reads as owned): equip immediately.
        if store.isOwned(theme.productID) {
            commitThemeSelection(index: index)
            return
        }

        // Paid and not yet owned: purchase, then equip on success.
        if let productID = theme.productID {
            Task {
                let success = await store.purchase(productID)
                if success, themes[index].productID == productID {
                    commitThemeSelection(index: index)
                }
            }
        }
    }

    private func commitThemeSelection(index: Int) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        withAnimation(.easeInOut(duration: 0.2).speed(motionSpeed)) {
            selectedThemeIndex = index
        }
        cardBackSelection.selectedName = themes[index].logoCard

        withAnimation(.spring(response: 1, dampingFraction: 0.7).speed(motionSpeed)) { //send the user back to the main menu
            showingThemes = false
        }

    }

    @ViewBuilder
    private var priceText: some View {
        let theme = themes[activeThemeIndex]
        let isWinLocked = (theme.requiredWins.map { WinTracker.shared.totalWins < $0 }) ?? false
        let isOwned = !isWinLocked && (theme.productID == nil || store.isOwned(theme.productID!))
        Group {
            if isWinLocked, let required = theme.requiredWins {
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                    Text(required == 1 ? "Win a game" : "Win two games")
                }
            } else if isOwned {
                Text("Owned") //single branch covers both free themes and paid-but-owned themes so SwiftUI sees no structural change between them
            } else if let productID = theme.productID {
                if isRestoring {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else if showingRestore {
                    Button {
                        let speed = motionSpeed
                        Task {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8).speed(speed)) {
                                isRestoring = true
                            }
                            await store.restore()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8).speed(speed)) {
                                isRestoring = false
                                showingRestore = false
                            }
                        }
                    } label: {
                        Text("Restore Purchases").underline()
                    }
                    .buttonStyle(.plain)
                } else if let price = store.displayPrice(for: productID) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8).speed(motionSpeed)) {
                            showingRestore = true
                        }
                    } label: {
                        if theme.isFullDeck {
                            Text("\(price) - Full Deck")
                        } else {
                            Text("\(price) - Card Back")
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(verbatim: "—") // products still loading or fetch failed
                }
            }
        }
        .onChange(of: activeThemeIndex) { _, _ in
            showingRestore = false
        }
        .onChange(of: showingThemes) { _, newValue in
            if !newValue { showingRestore = false }
        }
    }
    
    
    // MARK: - Gin Submenu
    private var ginSubmenuView: some View {
        ZStack {
            if isExpanded {
                ginExpandedSubmenu
                    .transition(.opacity)
            } else {
                ginCompactSubmenu
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25).speed(motionSpeed), value: isExpanded)
        .transition(.offset(y: UIScreen.main.bounds.height / 2))
    }
    
    private var ginCompactSubmenu: some View {
        ZStack(alignment: .topLeading) {
            backButton
                .padding(.leading, 30)
                
            HStack {
                Spacer()
                deckSection
                    .zIndex(999)
                    .padding(.top, 40)
                Spacer()
                
                VStack(spacing: 20) {
                    startButton
                    handSizePicker
                }
                .padding(.trailing, 10)
            }
        }
    }
    
    private var ginExpandedSubmenu: some View {
        VStack {
            backButton
                .rotationEffect(.degrees(-90))
                .padding(.vertical)
            startButton
            Spacer()
            deckSection
            Spacer()
            handSizePicker
            Spacer()
            Spacer()
        }
    }
    
    
    // MARK: - Crazy 8s Submenu
    private var crazy8sSubmenuView: some View {
        ZStack {
            if isExpanded {
                crazy8sExpandedSubmenu
                    .transition(.opacity)
            } else {
                crazy8sCompactSubmenu
                    .transition(.opacity)
            }
        }
        //claim the full screen so the compact submenu centres identically to Gin's,
        //without rendering a hidden ginExpandedSubmenu just to borrow its size
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.25).speed(motionSpeed), value: isExpanded)
        .transition(.offset(y: UIScreen.main.bounds.height / 2))
    }
    
    private var crazy8sCompactSubmenu: some View {
        ZStack(alignment: .topLeading) {
            backButton
                .padding(.leading, 30)
                
            HStack {
                Spacer()
                deckSection
                    .zIndex(999)
                    .padding(.top, 50)
                    .rotationEffect(.degrees(-10), anchor: .top)
                Spacer()
                
                VStack(spacing: 20) {
                    startButton
                        .offset(x: 0, y: 100) //offset moves the start button down, but doesnt affect the layout
                    handSizePicker
                        .hidden() //makes the handSizePicker here invisible and non-interactive, but it still affects spacing
                }
                .padding(.trailing, 10)
            }
        }
    }
    
    private var crazy8sExpandedSubmenu: some View {
        VStack {
            Spacer()
            backButton
                .rotationEffect(.degrees(-90))
                //.padding(.vertical)
            Spacer()
            startButton
            Spacer()
            deckSection
            Spacer()
            Spacer()
        }
    }
    
    
    // MARK: - Golf Submenu
    private var golfSubmenuView: some View {
        ZStack {
            if isExpanded {
                golfExpandedSubmenu
                    .transition(.opacity)
            } else {
                golfCompactSubmenu
                    .transition(.opacity)
            }
        }
        //claim the full screen so the compact submenu centres identically to Gin's,
        //without rendering a hidden ginExpandedSubmenu just to borrow its size
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.25).speed(motionSpeed), value: isExpanded)
        .transition(.offset(y: UIScreen.main.bounds.height / 2))
    }
    
    /// Height a compact submenu body occupies in the Gin/Crazy 8s layout (deck art plus the
    /// hand-size picker column). Golf has no picker, so it reserves this height with a plain
    /// spacer rather than laying out a hidden picker column just to borrow its size.
    private let compactSubmenuBodyHeight: CGFloat = 290

    private var golfCompactSubmenu: some View {
        ZStack(alignment: .topLeading) {
            backButton
                .padding(.leading, 30)

            Color.clear
                .frame(maxWidth: .infinity, maxHeight: compactSubmenuBodyHeight) // reserves the same body space as the other games
                .overlay(alignment: .top) {
                    ZStack(alignment: .top) {
                        golfDeckGrid
                            .zIndex(999)
                            .padding(.top, 80)

                        startButton
                    }
                }
        }
    }
    
    private var golfExpandedSubmenu: some View {
        VStack {
            Spacer()
            backButton
                .rotationEffect(.degrees(-90))
                //.padding(.vertical)
            Spacer()
            startButton
            Spacer()
            golfDeckGrid
            Spacer()
            Spacer()
        }
    }
    
    private var golfDeckGrid: some View {
        let verticalSpacing: CGFloat = 20
        let horizontalSpacing: CGFloat = 25
        
        return VStack(spacing: verticalSpacing) {
            ForEach(0..<2, id: \.self) { row in
                HStack(spacing: horizontalSpacing) {
                    ForEach(0..<3, id: \.self) { col in
                        
                        let i = (row * 3) + col
                        let animationRank = golfAnimationOrder.firstIndex(of: i) ?? 0
                        let isAnimated = animationRank < cardsAnimatedAway
                        let isHidden = animationRank < hiddenAnimatedAwayCards
                        
                        ZStack {
                            if animationRank == 5 {
                                Image(jokerCardName)
                                    .resizable()
                                    .aspectRatio(0.7, contentMode: .fit)
                                    .frame(height: 150)
                                
                                Group {
                                    Image(systemName: "bubble.left.fill")
                                        .font(.system(size: 50))
                                        .offset(x: 40, y: -80)
                                        .foregroundColor(.white)
                                        .shadow(radius: 5)
                                    
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 30))
                                        .offset(x: 40, y: -85)
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, Color(uiColor: .systemBlue))
                                }
                                .opacity(cardsAnimatedAway < 7 ? 0 : 1)
                                .scaleEffect(isBubblePulsating ? 1.05 : 1.0)
                                .onChange(of: cardsAnimatedAway) { _, newValue in
                                    if newValue == 8 {
                                        if (activeSubmenu == .golf) {
                                            withAnimation(.easeInOut(duration: 0.8).speed(motionSpeed).repeatForever(autoreverses: true)) {
                                                isBubblePulsating = true
                                            }
                                        }
                                    }
                                }
                                .onDisappear {
                                    isBubblePulsating = false // resets the state so it can animate again next time!
                                }
                            }
                            
                            let cardHeight: CGFloat = 150
                            let cardWidth: CGFloat = cardHeight * 0.7

                            // Math to collapse the 3x2 grid inward to a single central point
                            // Col 0 moves right, Col 2 moves left. Row 0 moves down, Row 1 moves up.
                            let convergeX = CGFloat(1 - col) * (cardWidth + horizontalSpacing)
                            let convergeY = CGFloat(0.5 - Double(row)) * (cardHeight + verticalSpacing)

                            // Calculate the general upward shift to hit the middle of the screen
                            let verticalShiftToCenter = -(UIScreen.main.bounds.height / 2)
                            let targetRotation = Double(col - 1) * -45.0
                            
                            // The animating card back
                            Image(cardBackSelection.selectedName)
                                .resizable()
                                .aspectRatio(0.7, contentMode: .fit)
                                .frame(height: cardHeight)
                                .rotationEffect(isAnimated ? Angle(degrees: targetRotation) : Angle(degrees: 0))
                                .offset(
                                    x: isAnimated ? (isIpad ? 500 : convergeX) : 0,
                                    y: isAnimated ? (isIpad ? 250 : verticalShiftToCenter + convergeY) : 0
                                )
                                .shadow(radius: 4, x: 2, y: 2)
                                .opacity(isHidden ? 0 : 1)
                        }
                    }
                }
            }
        }
    }
    
    
    // MARK: - Submenu Layout Components
    private var backButton: some View {
        Button(action: {
            isCardWheelHidden = false
            withAnimation(.easeInOut(duration: 0.2).speed(motionSpeed)) {
                activeSubmenu = nil
            }
            withAnimation(.linear(duration: 0.05).delay(0.1).speed(motionSpeed)) { // Bring the title back
                isTitleBarHidden = false
            }
            let speed = motionSpeed
            Task {
                try? await Task.sleep(nanoseconds: UInt64(200_000_000.0 / speed))
                cardsAnimatedAway = 0
                hiddenAnimatedAwayCards = 0
                jokerIsRed = Bool.random() //fresh red/black flip for the next reveal
                golfAnimationOrder = [0, 1, 2, 3, 5].shuffled() + [4]
            }
        }) {
            Image(systemName: "chevron.left")
                .font(.title3.weight(.bold))
                .foregroundColor(.primary)
                .padding(14)
                .background(.ultraThinMaterial, in: Circle()) // Liquid glass effect!
                .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Back", comment: "VoiceOver accessibility label – back button to return to the main menu"))
        .accessibilityAddTraits(.isButton)
        .accessibilityInputLabels([
            Text("Back", comment: "Voice Control input label – back button"),
            Text("Back to main menu", comment: "Voice Control input label – back button alternative phrasing"),
            Text("Dismiss", comment: "Voice Control input label – back / dismiss button"),
            Text("Exit", comment: "Voice Control input label – back / exit button"),
            Text("Left Arrow", comment: "Voice Control input label – the chevron icon on the back button"),
        ])
    }
    
    private var deckSection: some View {
        ZStack {
            Image(jokerCardName)
                .resizable()
                .aspectRatio(0.7, contentMode: .fit)
                .frame(height: viewModel.presentationStyle == .expanded ? 200 : 150)
            
            Group {
                Image(systemName: "bubble.left.fill")
                    .font(.system(size: 50))
                    .offset(x: 40, y: -80)
                    .foregroundColor(.white)
                    .shadow(radius: 5)
                
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .offset(x: 40, y: -85)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color(uiColor: .systemBlue))
            }
            .rotationEffect(.degrees(activeSubmenu == .crazy8s ? 10 : 0), anchor: .top)
            .opacity(cardsAnimatedAway < 6 ? 0 : 1)
            .scaleEffect(isBubblePulsating ? 1.05 : 1.0)
            .onChange(of: cardsAnimatedAway) { _, newValue in
                if newValue == 7 {
                    if (activeSubmenu == .ginRummy || activeSubmenu == .crazy8s) {
                        withAnimation(.easeInOut(duration: 0.8).speed(motionSpeed).repeatForever(autoreverses: true)) {
                            isBubblePulsating = true
                        }
                    }
                }
            }
            .onDisappear {
                isBubblePulsating = false // resets the state so it can animate again next time!
            }
            
            ForEach(0..<5) { i in
                Image(cardBackSelection.selectedName)
                    .resizable()
                    .aspectRatio(0.7, contentMode: .fit)
                    .frame(height: viewModel.presentationStyle == .expanded ? 200 : 150) // Make cards bigger in expanded!
                    .rotationEffect(i >= 5 - cardsAnimatedAway ? Angle(degrees: 45) : Angle(degrees: 0))
                    .offset(x: i >= 5 - cardsAnimatedAway ? (isIpad ? 400 : 225) : CGFloat(-i) * 3,
                            y: i >= 5 - cardsAnimatedAway ? (isIpad ? 300 : -450) : CGFloat(-i) * 3)
                    .shadow(radius: i == 0 ? 8 : 4, x: 2, y: 2) // 0 is the bottom card
                    .opacity(i >= 5 - hiddenAnimatedAwayCards ? 0 : 1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cardsAnimatedAway >= 5
            ? Text("Joker card", comment: "VoiceOver accessibility label for the joker card image revealed after the deck animates away")
            : Text("Deck of cards", comment: "VoiceOver accessibility label for the deck-of-cards image in the submenu"))
        .accessibilityAddTraits(.isImage)
    }
    
    private var startButton: some View {
        Button(action: {
            let speed = motionSpeed
            DispatchQueue.global(qos: .userInitiated).async {
                let selectedGameType = availableGames[activeGameIndex].type
                onStartGame(selectedGameType, handSize)
                DispatchQueue.main.async {
                    withAnimation(.spring(duration: 0.8)) { //animaiton ignores speed modifier. the game being created in the text field does not slow down
                        cardsAnimatedAway += 1
                    }
                    if cardsAnimatedAway <= 5 {
                        SoundManager.instance.playCardDeal()
                    }
                    if (activeSubmenu == .golf && cardsAnimatedAway == 6) {
                        SoundManager.instance.playCardDeal()
                    }
                    Task { //wait exactly 0.7 seconds then hide the card instantly at the destination so we dont see it animating away
                        try? await Task.sleep(nanoseconds: UInt64(700_000_000.0 / speed))
                        await MainActor.run {
                            hiddenAnimatedAwayCards += 1
                        }
                    }
                }
            }
        }) {
            Text("New Game")
                .font(.system(size: isExpanded ? 40 : 28, weight: .bold, design: .serif))
                .foregroundColor(.white)
                .scaleEffect(isPulsating ? 1.05 : 1.0)
                .animation(cardsAnimatedAway < 7
                           ? .easeInOut(duration: 0.8).speed(motionSpeed).repeatForever(autoreverses: true)
                           : .default,
                    value: isPulsating
                )
                .onAppear {
                    isPulsating = true
                }
                .onChange(of: cardsAnimatedAway) { _, newValue in
                    if newValue >= (activeSubmenu == .golf ? 8 : 7) {
                        isPulsating = false
                    }
                }
                .onDisappear {
                    isPulsating = false
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 15).fill(Color.black.opacity(0.3)).offset(y: 4) //depth layer
                        RoundedRectangle(cornerRadius: 15).fill(LinearGradient(colors: [Color(white: 0.3), Color(white: 0.1)], startPoint: .top, endPoint: .bottom)) //main button body
                    }
                )
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.2), lineWidth: 2))
                .shadow(color: .black.opacity(0.2), radius: 5, x: 5, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("New Game", comment: "VoiceOver accessibility label – button that starts a new game and attaches it to the message"))
        .accessibilityInputLabels([
            Text("New Game", comment: "Voice Control input label – new game button"),
            Text("New", comment: "Voice Control input label – new game button shorthand"),
            Text("Create Game", comment: "Voice Control input label – new game button alternative phrasing"),
            Text("Start Game", comment: "Voice Control input label – new game button alternative phrasing"),
            Text("Play", comment: "Voice Control input label – new game button shorthand"),
        ])
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text("Attaches the game to your message so you can send it.", comment: "VoiceOver accessibility hint describing what the New Game button does"))
    }
    
    private var handSizePicker: some View {
        VStack(spacing: 40) {
            Text("Hand Size:")
                .font(.system(size: isExpanded ? 30 : 20, weight: .semibold, design: .serif))
                .foregroundColor(.white)
                .accessibilityAddTraits(.isHeader)
            
            HStack(spacing: 30) {
                cardOption(selectedHandSize: 7, imageName: card7Image, tilt: -8) //left card
                cardOption(selectedHandSize: 10, imageName: card10Image, tilt: 8) //right card
            }
        }
        .onAppear {
            card7Image = "7\(suits.randomElement() ?? "Hearts")"
            card10Image = "10\(suits.randomElement() ?? "Spades")"
        }
    }
    
    @ViewBuilder
    private func cardOption(selectedHandSize: Int, imageName: String, tilt: Double) -> some View {
        let isSelected = (handSize == selectedHandSize)
        let suit = imageName.replacingOccurrences(of: String(selectedHandSize), with: "") //for edge case accessibility addressing
        
        Image(cardBackSelection.themedFrontName(for: imageName))
            .resizable()
            .aspectRatio(0.7, contentMode: .fit)
            .frame(height: 150)
            .cornerRadius(8)
            .shadow(color: isSelected ? .white.opacity(0.5) : .black.opacity(0.3), radius: isSelected ? 15 : 5)
            .rotationEffect(.degrees(tilt))
            .offset(x: tilt * -2)
            // ANIMATION LOGIC:
            .scaleEffect(isSelected ? 1.1 : 1) // Selected is bigger, non-selected is shorter
            .zIndex(isSelected ? 2 : 1)
            .offset(y: isSelected ? -15 : 15)     // Selected goes up, non-selected goes down
            .brightness(isSelected ? 0 : -0.2)    // Dim the non-selected card slightly
            .onTapGesture {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6).speed(motionSpeed)) {
                    handSize = selectedHandSize
                }
            }
            // ACCESSIBILITY MODIFIERS:
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore) // Ignore default image reading
            .accessibilityLabel(Text("\(selectedHandSize) cards", comment: "VoiceOver accessibility label for a hand-size option card, e.g. '7 cards'")) // What VoiceOver reads
            .accessibilityInputLabels([
                Text("\(selectedHandSize)"),
                Text("\(selectedHandSize) cards", comment: "Voice Control input label – hand-size option, e.g. '7 cards'"),
                Text("\(selectedHandSize) of \(suit)", comment: "Voice Control input label – hand-size option matching the displayed card, e.g. '7 of Hearts'"),
            ]) // What Voice Control listens for
            .accessibilityAddTraits(.isButton) // Tells the system it's clickable
            .accessibilityAddTraits(isSelected ? .isSelected : []) // Announces the visual state
    }
}

/// Places the eagle along its pass: turns one 0-to-1 progress into a position on a very shallow swoop —
/// in from off the right a little above the band it crosses, down to that band dead center, then back up
/// and out the left. Only the height is shaped here; progress maps straight onto the horizontal travel,
/// so the eagle crosses at one constant speed however the swoop is tuned.
///
/// Each half is a parabola, and both meet the center flat, so the dip bottoms out smoothly instead of
/// creasing. Their sizes are written as the height the eagle sits at while crossing the *edge of the
/// screen*, not at the ends of its travel: the travel runs half a screen past each edge, so the tallest,
/// steepest part of each parabola is always off-screen and the numbers here would badly overstate the
/// swoop if they were read as its extremes.
private struct EagleGlide: GeometryEffect {
    var progress: Double
    let screenWidth: CGFloat

    /// Heights, in points, at which the eagle crosses each edge of the screen. Small on purpose — the
    /// swoop should read as a drift rather than a dive. The exit sits a little above the entrance so the
    /// pass finishes climbing away, instead of just returning to the height it came in at.
    private static let entryRise: CGFloat = 10
    private static let exitRise: CGFloat = 14

    /// Half the horizontal travel: the eagle starts a full screen width right of center and finishes a
    /// full width left of it, well clear of both edges.
    private var travelExtent: CGFloat { screenWidth }
    /// Where the edge of the screen falls along that travel, as a fraction of it.
    private var edgeFraction: CGFloat { (screenWidth / 2) / travelExtent }

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let position = 1 - 2 * CGFloat(progress) //+1 off the right at the start, -1 off the left at the end
        let rise = position > 0 ? Self.entryRise : Self.exitRise //taller half on the way out
        let edges = position / edgeFraction //1 as it crosses an edge of the screen, 0 dead center
        return ProjectionTransform(CGAffineTransform(
            translationX: position * travelExtent,
            y: -rise * edges * edges //negative is up: highest at the ends, level with the band in the middle
        ))
    }
}

/// Places the koi along its leap: turns one 0-to-1 progress into a position and the heading to match, so
/// the fish banks into each curve rather than sliding along it flat.
///
/// The jump is two quadratic Beziers with the apex between them, off the top of the screen: the first
/// carries the fish from the left edge up and out, the second brings it back in further right and down
/// to the waterline, where it swims off to the right. Progress arrives linear and is eased *inside* each
/// arc — decelerating on the way up, accelerating on the way down — which is what makes the two halves
/// read as one thrown arc rather than two unrelated passes.
private struct KoiArc: GeometryEffect {
    var progress: Double
    let screenWidth: CGFloat
    /// Offset that puts the fish clear of the top of the screen — negative, i.e. upwards.
    let exitY: CGFloat

    private static let gapShare: Double = 0.02  //coasting over the apex, entirely off-screen
    private static let leapShare: Double = (1 - gapShare) / 2 //the climb and the dive split the rest evenly
    private static var diveStart: Double { leapShare + gapShare }
    /// How sharply each arc eases. Kept mild on purpose: the steeper the ease, the more of the run the
    /// fish spends crawling through the off-screen ends of its arcs instead of visibly crossing the screen.
    private static let easeExponent: Double = 1.4
    /// How far past the side of the screen each arc starts and ends, so the fish is fully hidden there.
    private static let sideMargin: CGFloat = 35
    /// How far *past* the center each arc carries before it turns around, as a fraction of the screen
    /// width. The two arcs therefore overlap horizontally, above the top edge where none of it shows.
    /// What the eye tracks isn't where an arc ends but where the fish crosses that edge, and the two
    /// move in opposite directions as this grows: the climb goes out further right, the dive comes back
    /// further left.
    ///
    /// Those two crossings coincide at about 0.05 — the fish then vanishes and returns on the same spot.
    /// Above that they trade places, so it returns to the *left* of where it left: at the value set here
    /// that's a ~105pt backwards step, taken at the very top of the screen. That's the deliberate trade —
    /// a wider, later exit and an earlier entrance, bought with that step — and it buys no extra
    /// on-screen time, so this constant is purely about where the crossings sit.
    ///
    /// Far enough out that the arcs now intersect *below* the top edge rather than above it, which is
    /// what makes the visible shape an X rather than a peak: the fish leaves the frame still climbing
    /// and comes back already falling, so the apex it's arcing over is never actually on screen.
    private static let apexOverlap: CGFloat = 0.20
    /// How far along each arc its control point sits. High, so the fish tracks the waterline on the way
    /// in and then whips up steeply as it leaves, rather than drifting across on a lazy diagonal.
    private static let controlBias: CGFloat = 0.70

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let (arc, t) = segment(at: progress)
        let position = arc.point(at: t)
        //A GeometryEffect's transform is applied in the view's own space, whose origin is its top-left
        //corner, so the rotation is sandwiched between a move to the fish's center and back — otherwise
        //it would swing the fish around that corner instead of turning it in place.
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let transform = CGAffineTransform.identity
            .translatedBy(x: position.x, y: position.y)
            .translatedBy(x: center.x, y: center.y)
            .rotated(by: arc.heading(at: t))
            .translatedBy(x: -center.x, y: -center.y)
        return ProjectionTransform(transform)
    }

    /// Which arc the fish is on at `progress`, and how far along it is once eased. The coast over the
    /// apex parks it at the end of the climb, which is already off-screen, so nothing shows during it.
    ///
    /// The easing runs the way it does because the apex is off-screen: what's actually on screen is the
    /// fish powering up out of the water and, later, hitting it again and gliding away. So the climb
    /// accelerates and the descent slows, and the projectile's own deceleration into the apex and fall
    /// back out of it happen out of frame, in the arcs' eased ends.
    private func segment(at progress: Double) -> (Bezier, CGFloat) {
        if progress < Self.leapShare {
            let u = progress / Self.leapShare
            return (leapArc, CGFloat(pow(u, Self.easeExponent))) //builds speed as it drives up and out
        }
        if progress < Self.diveStart {
            return (leapArc, 1)
        }
        let u = min((progress - Self.diveStart) / (1 - Self.diveStart), 1)
        return (diveArc, CGFloat(1 - pow(1 - u, Self.easeExponent))) //sheds it again against the water
    }

    /// Up and out: enters level with the water off the left edge, banks upward, and crosses the top of
    /// the screen dead center, carrying a little past it before the arc ends. The control point sits back
    /// at the waterline so the fish swims in flat before the curve lifts it — the bend *is* the leap.
    private var leapArc: Bezier {
        let start = CGPoint(x: -screenWidth / 2 - Self.sideMargin, y: 0)
        let end = CGPoint(x: screenWidth * Self.apexOverlap, y: exitY)
        return Bezier(start: start,
                      control: CGPoint(x: start.x + (end.x - start.x) * Self.controlBias, y: 0),
                      end: end)
    }

    /// Down and away: starts back past center, comes down through the top edge dead center nose-first,
    /// then flattens out into the water and swims off the right edge. Point for point `leapArc` run
    /// backwards — mirrored endpoints, same control bias measured from the far end — so the two together
    /// are one symmetric jump, and the fish reappears exactly where it went out.
    private var diveArc: Bezier {
        let start = CGPoint(x: -screenWidth * Self.apexOverlap, y: exitY)
        let end = CGPoint(x: screenWidth / 2 + Self.sideMargin, y: 0)
        return Bezier(start: start,
                      control: CGPoint(x: end.x - (end.x - start.x) * Self.controlBias, y: 0),
                      end: end)
    }

    /// Quadratic Bezier — one smooth bend, and cheap enough to differentiate for the heading every frame.
    private struct Bezier {
        let start: CGPoint
        let control: CGPoint
        let end: CGPoint

        func point(at t: CGFloat) -> CGPoint {
            let inverse = 1 - t
            return CGPoint(
                x: inverse * inverse * start.x + 2 * inverse * t * control.x + t * t * end.x,
                y: inverse * inverse * start.y + 2 * inverse * t * control.y + t * t * end.y
            )
        }

        /// Angle of the curve's tangent in radians — the direction the fish is actually travelling.
        func heading(at t: CGFloat) -> CGFloat {
            let dx = 2 * (1 - t) * (control.x - start.x) + 2 * t * (end.x - control.x)
            let dy = 2 * (1 - t) * (control.y - start.y) + 2 * t * (end.y - control.y)
            return atan2(dy, dx)
        }
    }
}

// MARK: - Init & Helper structs/classes
class MenuViewModel: ObservableObject { //tracks presentation style and chat type
    @Published var presentationStyle: MSMessagesAppPresentationStyle
    @Published var is1v1: Bool //true in a 1-on-1 chat (or when texting yourself for testing); false in a group chat

    init(presentationStyle: MSMessagesAppPresentationStyle, is1v1: Bool = true) {
        self.presentationStyle = presentationStyle
        self.is1v1 = is1v1
    }
}

struct MenuGame: Identifiable {
    let id = UUID()
    var type: GameType
    /// Stable English identifier — used as the localization key and as the WinTracker/Game Center
    /// key. NOT for display; use ``displayTitle`` for anything shown to the player.
    var title: String
    var wins: Int = 0

    /// The player-facing title. For Crazy 8s this follows the region's rule variant
    /// (Crazy 8s / Mau-Mau / Switch); other games resolve their localized `title`.
    var displayTitle: String {
        switch type {
        case .crazy8s: return Crazy8sVariant.forCurrentRegion().displayName
        default:       return String(localized: String.LocalizationValue(title))
        }
    }

    /// The localized title-text overlay for this card. Localization is handled inside the asset
    /// catalog, so the asset name is fixed per game type. Crazy 8s additionally swaps the text
    /// image to match the region's rule variant, mirroring ``artName``.
    var titleTextName: String {
        switch type {
        case .ginRummy: return "ginRummyTitleText"
        case .golf:     return "golfTitleText"
        case .crazy8s:
            switch Crazy8sVariant.forCurrentRegion() {
            case .crazy8s:     return "crazy8sTitleText"
            case .mauMau:      return "mauMauTitleText"
            case .irishSwitch: return "switchTitleText"
            case .pesten:      return "pestenTitleText"
            }
        case .unknown:  return ""
        }
    }

    /// The art overlay for this card. Gin Rummy and Golf always use their single art. Crazy 8s swaps
    /// to the knight art whenever the creator's region plays a non–Crazy 8s variant (Mau-Mau in the
    /// German-speaking regions and Brazil, Switch in the UK/Ireland) and uses the spider art otherwise.
    var artName: String {
        switch type {
        case .ginRummy: return "ginRummyArt"
        case .golf:     return "golfArt"
        case .crazy8s:  return Crazy8sVariant.forCurrentRegion() == .crazy8s ? "crazy8sSpiderArt" : "crazy8sKnightArt"
        case .unknown:  return ""
        }
    }

    /// The composited logo card — `blankCard` base + art overlay + localized title text, baked once
    /// into a single flattened bitmap (see ``GameLogoCard``) and cached.
    var logoImage: UIImage { GameLogoCard.image(for: self) }
}

/// Bakes each game's main-menu title card from separate asset-catalog layers — a shared `blankCard`
/// base, a game-specific art overlay, and a localized title-text overlay — into one flattened `UIImage`.
///
/// This keeps the asset catalog small: one shared base, one art layer, and one localizable text layer
/// per game, instead of a fully pre-rendered card image for every supported language. Flattening the
/// layers up front also means SwiftUI draws a single bitmap rather than compositing a `ZStack` of
/// images on the GPU every frame while the card wheel animates.
enum GameLogoCard {
    /// Baked cards keyed by title-text asset name (unique per game). The region-resolved art and the
    /// locale-resolved title are both fixed for the life of the session, so caching by game is stable.
    private static var cache: [String: UIImage] = [:]

    /// The shared, un-localized base layer every card is drawn on top of.
    private static let baseCardName = "blankCard"

    static func image(for game: MenuGame) -> UIImage {
        if let cached = cache[game.titleTextName] { return cached }
        let baked = bake(artName: game.artName, titleTextName: game.titleTextName)
        cache[game.titleTextName] = baked
        return baked
    }

    private static func bake(artName: String, titleTextName: String) -> UIImage {
        // Bottom-to-top draw order: base card, art overlay, then the localized title text on top.
        let layerNames = [baseCardName, artName, titleTextName]
        let layers = layerNames.compactMap { UIImage(named: $0) }

        // All layers are authored at the same pixel dimensions, so the base defines the canvas.
        guard let base = layers.first else { return UIImage() }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = base.scale   // preserve the source artwork's native scale
        format.opaque = false       // cards have rounded, transparent corners

        let renderer = UIGraphicsImageRenderer(size: base.size, format: format)
        return renderer.image { _ in
            let rect = CGRect(origin: .zero, size: base.size)
            for layer in layers {
                layer.draw(in: rect)
            }
        }
    }
}
