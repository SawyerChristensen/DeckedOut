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
        MenuGame(type: .ginRummy, title: "Gin Rummy", logoCard: "ginRummyCard"),
        MenuGame(type: .crazy8s, title: "Crazy 8s", logoCard: "crazy8sCard"),
        MenuGame(type: .golf, title: "Golf", logoCard: "golfCard")
    ]
    private static var themes: [DeckTheme] { DeckTheme.all }
    private var themes: [DeckTheme] { DeckTheme.all }
    private var isThemeSelected: Bool { activeThemeIndex == selectedThemeIndex }
    private var isActiveThemeWinLocked: Bool {
        guard let required = themes[activeThemeIndex].requiredWins else { return false }
        return WinTracker.shared.totalWins < required
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
    }
    
    private var gameTitleFace: some View {
        Text(LocalizedStringKey(availableGames[activeGameIndex].title))
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
            .accessibilityLabel(Text("Selected game: \(availableGames[activeGameIndex].title)", comment: "VoiceOver accessibility label that announces the currently selected game, e.g. 'Selected game: Crazy 8s'"))
            .accessibilityHidden(showingThemes)
    }

    private var themeTitleFace: some View {
        Text(LocalizedStringKey(themes[activeThemeIndex].title))
            .font(.largeTitle)
            .fontWeight(.semibold)
            .fontDesign(.serif)
            .foregroundColor(.white)
            .shadow(color: .white.opacity(0.33), radius: 5)
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
        .accessibilityLabel(Text("\(availableGames[activeGameIndex].title) win count: \(availableGames[activeGameIndex].wins)", comment: "VoiceOver accessibility label that announces the win count for a specific game, e.g. 'Crazy 8s win count: 5'"))
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
                        Palette.bookBrown // Tertiary (Layer 3)
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
                
            } else if !isThemeSelected { // Selecting a NEW theme
                let theme = themes[activeThemeIndex]
                if let required = theme.requiredWins, WinTracker.shared.totalWins < required { //the user is attempting to select a win-locked theme
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                } else if store.isOwned(theme.productID) { //if its owned, select it
                    commitThemeSelection()
                } else if let productID = theme.productID { //user is purchasing a new theme!
                    Task {
                        let success = await store.purchase(productID)
                        if success, themes[activeThemeIndex].productID == productID {
                            commitThemeSelection()
                        }
                    }
                }
            } else {
                // Trying to select the ALREADY SELECTED theme (Error haptic)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
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
        ZStack {
            // Game wheel — each card flips individually in place when showingThemes toggles.
            gameCardWheel
                .modifier(FlipOpacity(rotation: showingThemes ? 180 : 0))
                .allowsHitTesting(!showingThemes)
                .accessibilityHidden(showingThemes)
                .accessibilityElement(children: showingThemes ? .ignore : .contain)

            // Theme wheel — flips in to replace the game wheel; both card faces match.
            themeCardWheel
                .modifier(FlipOpacity(rotation: showingThemes ? 0 : 180))
                .allowsHitTesting(showingThemes)
                .accessibilityHidden(!showingThemes)
                .accessibilityElement(children: showingThemes ? .contain : .ignore)
        }
        //.zIndex(999) //keep the cards on top
        .frame(maxWidth: UIScreen.main.bounds.width) //dont let the cards expand the zstack when they fan out
        .scaleEffect(isExpanded ? 1.4 : 1.1)
        .offset(y: isExpanded ? (isInSubmenu ? -175 : 5) : 40) //40: in compact main menu
        .opacity(isCardWheelHidden ? 0 : 1)
        .accessibilityHidden(isCardWheelHidden)
    }

    private var gameCardWheel: some View {
        MenuCardWheel(
            games: availableGames,
            showingThemes: showingThemes,
            onActiveIndexChange: { newIndex, direction in // handle real-time mid-swipe updates
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
            userSelectedGame: { index in // handle selecting a game
                withAnimation(.easeInOut(duration: 0.2).speed(motionSpeed)) {
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

    private var themeCardWheel: some View {
        ThemeCardWheel(
            themes: themes,
            initialIndex: activeThemeIndex,
            showingThemes: showingThemes,
            selectedIndex: selectedThemeIndex,
            onActiveIndexChange: { newIndex, direction in
                if activeThemeIndex != newIndex {
                    themeTitleTransitionEdge = (direction == .trailing) ? .leading : .trailing
                    withAnimation(.easeInOut(duration: 0.2).speed(motionSpeed)) {
                        activeThemeIndex = newIndex
                    }
                }
            },
            onThemeSelected: { selectedIndex in
                let theme = themes[selectedIndex]

                if let required = theme.requiredWins, WinTracker.shared.totalWins < required {
                    return // Theme is locked! Add haptic error buzz?
                }

                cardBackSelection.selectedName = theme.logoCard // Commit the theme change to the global store

                // Update the local UI state and animate the menu closing
                withAnimation(.spring(response: 1, dampingFraction: 0.7).speed(motionSpeed)) {
                    selectedThemeIndex = selectedIndex
                    showingThemes = false
                }
            }
        )
    }
    
    
    // MARK: - Menu helper functions
    private func preloadWins() {
        for index in availableGames.indices {
            let title = availableGames[index].title
            availableGames[index].wins = WinTracker.shared.getWinCount(for: title)
        }
    }

    //distills the priceText into a stable key — identical labels (e.g. two Owned themes) share an id so no slide fires
    private var priceTextKey: String {
        let theme = themes[activeThemeIndex]
        if let required = theme.requiredWins, WinTracker.shared.totalWins < required {
            return "winlock:\(required)"
        }
        guard let productID = theme.productID else { return "owned" }
        if store.isOwned(productID) { return "owned" }
        if isRestoring { return "restoring" }
        if showingRestore { return "restore" }
        if let price = store.displayPrice(for: productID) { return "price:\(price)" }
        return "loading"
    }

    private func commitThemeSelection() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        withAnimation(.easeInOut(duration: 0.2).speed(motionSpeed)) {
            selectedThemeIndex = activeThemeIndex
        }
        cardBackSelection.selectedName = themes[activeThemeIndex].logoCard

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
                        if price == "$0.99" {
                            Text("$0.99 - Card Back")
                        } else if price == "$1.99" || price == "1.99" { // Added safety for string formatting
                            Text("$1.99 - Full Deck")
                        } else {
                            Text(price)
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
            ginExpandedSubmenu
                .hidden() //here to match crazy8sSubmenuView size to ginSubmenuView
        }
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
            ginExpandedSubmenu
                .hidden() //here to match golfSubmenuView size to ginSubmenuView
        }
        .animation(.easeInOut(duration: 0.25).speed(motionSpeed), value: isExpanded)
        .transition(.offset(y: UIScreen.main.bounds.height / 2))
    }
    
    private var golfCompactSubmenu: some View {
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
            .hidden() // ^ just for reserving space
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
                                    .frame(height: 145)
                                
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
                            
                            let cardHeight: CGFloat = 145
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
                .frame(height: viewModel.presentationStyle == .expanded ? 200 : 145)
            
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
                    .frame(height: viewModel.presentationStyle == .expanded ? 200 : 145) // Make cards bigger in expanded!
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
            .frame(height: 145)
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
    var title: String
    var logoCard: String // The front of the card
    var wins: Int = 0
}
