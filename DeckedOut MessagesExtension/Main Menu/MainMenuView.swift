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
    @ObservedObject var viewModel: MenuViewModel
    private var isExpanded: Bool { viewModel.presentationStyle == .expanded }
    
    var onStartGame: (GameType, Int) -> Void //triggers createGame in MessagesViewController
    
    @State private var handSize = 7 //full game is normally 10, but 7 is quicker and better suited for mobile
    @State private var cardsAnimatedAway = 0
    @State private var golfAnimationOrder: [Int] = [0, 1, 2, 3, 5].shuffled() + [4]
    @State private var hiddenAnimatedAwayCards = 0
    @State private var isPulsating = false //for the "state game" text
    @State private var isBubblePulsating = false //for the joker's reminder bubble
    @State private var card7Image: String = "7Spades"
    @State private var card10Image: String = "10Clubs"
    let suits = ["Hearts", "Diamonds", "Clubs", "Spades"]
    
    @State private var titleTransitionEdge: Edge = .trailing
    @State private var themeTitleTransitionEdge: Edge = .trailing
    @State private var activeGameIndex: Int = 0
    @State private var activeThemeIndex: Int = MainMenuView.initialSelectedThemeIndex()
    @State private var selectedThemeIndex: Int = MainMenuView.initialSelectedThemeIndex()
    @State private var themeWheelKey: Int = 0
    @StateObject private var cardBackSelection = CardBackSelection.shared
    @State private var availableGames: [MenuGame] = [
        MenuGame(type: .ginRummy, title: "Gin Rummy", logoCard: "ginRummyCard"),
        MenuGame(type: .crazy8s, title: "Crazy 8s", logoCard: "crazy8sCard"),
        MenuGame(type: .golf, title: "Golf", logoCard: "golfCard")
    ]
    private static var themes: [CardBackTheme] { CardBackTheme.all }
    private var themes: [CardBackTheme] { CardBackTheme.all }
    private var isThemeSelected: Bool { activeThemeIndex == selectedThemeIndex }

    private static func initialSelectedThemeIndex() -> Int {
        let name = CardBackSelection.shared.selectedName
        return themes.firstIndex(where: { $0.logoCard == name })
            ?? themes.firstIndex(where: { $0.logoCard == CardBackSelection.defaultName })
            ?? 0
    }
    @State private var activeSubmenu: GameType? = nil
    private var isInSubmenu: Bool { activeSubmenu != nil }
    @State private var isTitleBarHidden: Bool = false
    @State private var isCardWheelHidden: Bool = false
    @State private var showingRules: Bool = false
    @State private var showingThemes: Bool = false
    @ScaledMetric(relativeTo: .title) private var scaledButtonUnit: CGFloat = 10
    private var buttonSize: CGFloat { isExpanded ? scaledButtonUnit * 7 : scaledButtonUnit * 4 }
    let isIpad = UIDevice.current.userInterfaceIdiom == .pad
  
    
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
                gameTitleBar

                midSection

                cardWheel
            }
        }
        .overlay {
            if showingRules {
                RulesView(gameType: availableGames[activeGameIndex].type, isExpanded: isExpanded) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingRules = false
                    }
                }
                .transition(.opacity)
            }
        }
        .background(backgroundLayer)
        .onAppear {
            preloadWins()
        }
    }
    
    
    private var backgroundLayer: some View {
        ZStack {
            Image("feltBackgroundLight") //Image(colorScheme == .dark ? "feltBackgroundDark" : "feltBackgroundLight")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            /*LinearGradient(
                gradient: Gradient(colors: [Color.white.opacity(0.1), Color.black.opacity(0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()*/
        }
    }
    
    private var gameTitleBar: some View {
        VStack(spacing: isExpanded ? 15 : 5) {
            ZStack {
                // Game title face
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
                    .animation(.easeInOut, value: activeGameIndex)
                    .modifier(FlipOpacity(rotation: showingThemes ? 180 : 0))

                // Theme title face — pre-rotated 180° so it shows on the back of the flip
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
                    .animation(.easeInOut, value: activeThemeIndex)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                    .modifier(FlipOpacity(rotation: showingThemes ? 0 : 180))
            }
            .padding(.top, isExpanded ? (isIpad ? 30 : 15) : 0) //pretty sure spacing doesnt include safearea - first element
            .scaleEffect(isExpanded ? 1.2 : 1)
            .rotation3DEffect(.degrees(showingThemes ? -180 : 0), axis: (x: 0, y: 1, z: 0))

            ZStack {
                // Win counter face
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
                }
                .modifier(FlipOpacity(rotation: showingThemes ? 180 : 0))

                // Price face
                Text(LocalizedStringKey(themes[activeThemeIndex].price ?? "Owned"))
                    .foregroundColor(.white)
                    .shadow(color: .white.opacity(0.33), radius: 5)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                    .modifier(FlipOpacity(rotation: showingThemes ? 0 : 180))
            }
            .font(isExpanded ? .headline : .subheadline)
            .fontWeight(.medium)
            .padding(.top, isExpanded ? 15 : 0)
            .contentTransition(.interpolate)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
            .scaleEffect(isExpanded ? 1.2 : 1)
            .rotation3DEffect(.degrees(showingThemes ? -180 : 0), axis: (x: 0, y: 1, z: 0))
            
    
            Divider()
                .opacity(0)
            
            Divider()
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
    }
    
    private var midSection: some View {
        Spacer()
            .frame(maxWidth: .infinity)
            /*.overlay( //this is so we can keep the vertical spacing of the Spacer() while injecting an HStack of different vertical spacing
                HStack {
                    rulesButton
                        //.padding(.leading, isExpanded ? (isIpad ? 290 : 110) : 25)
                    Spacer()
                    customizationButton
                        //.padding(.trailing, isExpanded ? (isIpad ? 290 : 110) : 25)
                }
                //.padding(.top, isExpanded ? -90 : 10)
                //.padding(.horizontal, isExpanded ? (isIpad ? 400 : 200) : 25)
                .opacity(isTitleBarHidden ? 0 : 1)
            )*/
            .overlay(alignment: .leading) {
                rulesButton
                    .padding(.leading, isExpanded ? (isIpad ? 250 : 75) : 25)
                    .padding(.top, isExpanded ? (isIpad ? -120 : -130) : 0)
                    .opacity(isTitleBarHidden ? 0 : 1)
            }
            .overlay(alignment: .trailing) {
                customizationButton
                    .padding(.trailing, isExpanded ? (isIpad ? 250 : 75) : 25)
                    .padding(.top, isExpanded ? (isIpad ? 70 : 100) : 0)
                    .opacity(isTitleBarHidden ? 0 : 1)
            }
    }
    
    private var cardWheel: some View {
        ZStack {
            // Game wheel — each card flips individually in place when showingThemes toggles.
            gameCardWheel
                .modifier(FlipOpacity(rotation: showingThemes ? 180 : 0))
                .allowsHitTesting(!showingThemes)

            // Theme wheel — flips in to replace the game wheel; both card faces match.
            themeCardWheel
                .modifier(FlipOpacity(rotation: showingThemes ? 0 : 180))
                .allowsHitTesting(showingThemes)
        }
        //.zIndex(999) //keep the cards on top
        .frame(maxWidth: UIScreen.main.bounds.width) //dont let the cards expand the zstack when they fan out
        .scaleEffect(isExpanded ? 1.4 : 1.1)
        .offset(y: isExpanded ? (isInSubmenu ? -175 : 5) : 40) //40: in compact main menu
        .opacity(isCardWheelHidden ? 0 : 1)
    }

    private var gameCardWheel: some View {
        MenuCardWheel(
            games: availableGames,
            showingThemes: showingThemes,
            onActiveIndexChange: { newIndex, direction in // handle real-time mid-swipe updates
                if activeGameIndex != newIndex {
                    titleTransitionEdge = direction
                    withAnimation(.easeInOut(duration: 0.2)) {
                        activeGameIndex = newIndex
                    }
                }
            },
            userSelectedGame: { index in // handle selecting a game
                withAnimation(.easeInOut(duration: 0.2)) {
                    activeSubmenu = availableGames[index].type
                }
                withAnimation(.linear(duration: 0.05).delay(0.12)) { //wait a bit then trigger a fast fade
                    isTitleBarHidden = true
                }
                Task {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
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
            onActiveIndexChange: { newIndex, direction in
                if activeThemeIndex != newIndex {
                    themeTitleTransitionEdge = direction
                    withAnimation(.easeInOut(duration: 0.2)) {
                        activeThemeIndex = newIndex
                    }
                }
            }
        )
        .id(themeWheelKey)
    }
    
    private var rulesButton: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            if showingThemes {
                withAnimation(.spring(response: 0.67, dampingFraction: 0.7)) {
                    showingThemes = false
                    activeThemeIndex = selectedThemeIndex
                }
            } else {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
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
                        .white,             // Primary (Layer 1)
                        Color(white: 0.3),  // Secondary (Layer 2)
                        Color("bookBrown") // Tertiary (Layer 3)
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
        }
        .buttonStyle(.plain) //turns off the accessibility background showing the button shape
    }

    private var customizationButton: some View {
        Button(action: {
            if !showingThemes { // Opening the themes menu
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                themeWheelKey += 1
                activeThemeIndex = selectedThemeIndex
                withAnimation(.spring(response: 0.67, dampingFraction: 0.7)) {
                    showingThemes = true
                }
                
            } else if !isThemeSelected { // Selecting a NEW theme
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedThemeIndex = activeThemeIndex
                }
                cardBackSelection.selectedName = themes[activeThemeIndex].logoCard
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
                    .saturation(showingThemes && isThemeSelected ? 0 : 1)
                    .shadow(color: .black.opacity(0.15), radius: 5, x: 5, y: 5)
                    .scaleEffect(buttonSize / iconRenderSize)
                    .frame(width: buttonSize, height: buttonSize)
                
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.plain) //turns off the accessibility background showing the button shape
    }
    
    // MARK: - Menu helper functins
    private func preloadWins() {
        for index in availableGames.indices {
            let title = availableGames[index].title
            availableGames[index].wins = WinTracker.shared.getWinCount(for: title)
        }
    }
    
    // MARK: - Gin Submenu
    private var ginSubmenuView: some View {
        ZStack {
            ginCompactSubmenu
                .opacity(isExpanded ? 0 : 1)
            ginExpandedSubmenu
                .opacity(isExpanded ? 1 : 0)
        }
        //.animation(.easeInOut(duration: 0.25), value: isExpanded)
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
    
    // MARK: - Crazy8s Submenu
    private var crazy8sSubmenuView: some View {
        ZStack {
            crazy8sCompactSubmenu
                .opacity(isExpanded ? 0 : 1)
            crazy8sExpandedSubmenu
                .opacity(isExpanded ? 1 : 0)
            ginExpandedSubmenu
                .hidden() //here to match crazy8sSubmenuView size to ginSubmenuView
        }
        //.animation(.easeInOut(duration: 0.25), value: isExpanded)
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
            golfCompactSubmenu
                .opacity(isExpanded ? 0 : 1)
            golfExpandedSubmenu
                .opacity(isExpanded ? 1 : 0)
            ginExpandedSubmenu
                .hidden() //here to match golfSubmenuView size to ginSubmenuView
        }
        //.animation(.easeInOut(duration: 0.25), value: isExpanded)
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
            .hidden() //just for reserving space
            .overlay(alignment: .top) {
                
                ZStack(alignment: .top) {
                    golfDeckGrid
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
                                Image("JokerCard")
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
                                            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
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
            withAnimation(.easeInOut(duration: 0.2)) {
                activeSubmenu = nil
            }
            withAnimation(.linear(duration: 0.05).delay(0.1)) { // Bring the title back
                isTitleBarHidden = false
            }
            Task {
                try? await Task.sleep(nanoseconds: 200_000_000)
                cardsAnimatedAway = 0
                hiddenAnimatedAwayCards = 0
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
    }
    
    private var deckSection: some View {
        ZStack {
            Image("JokerCard")
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
                        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
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
    }
    
    private var startButton: some View {
        Button(action: {
            DispatchQueue.global(qos: .userInitiated).async {
                let selectedGameType = availableGames[activeGameIndex].type
                onStartGame(selectedGameType, handSize)
                DispatchQueue.main.async {
                    withAnimation(.spring(duration: 0.7)) {
                        cardsAnimatedAway += 1
                    }
                    if cardsAnimatedAway <= 5 {
                        SoundManager.instance.playCardDeal()
                    }
                    if (activeSubmenu == .golf && cardsAnimatedAway == 6) {
                        SoundManager.instance.playCardDeal()
                    }
                    Task { //wait exactly 0.7 seconds then hide the card instantly at the destination so we dont see it animating away
                        try? await Task.sleep(nanoseconds: 700_000_000)
                        await MainActor.run {
                            hiddenAnimatedAwayCards += 1
                        }
                    }
                }
            }
        }) {
            Text("Start Game!")
                .font(.system(size: isExpanded ? 40 : 28, weight: .bold, design: .serif))
                .foregroundColor(.white)
                .scaleEffect(cardsAnimatedAway < 7 ? (isPulsating ? 1.05 : 1) : 1.0)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        isPulsating = true
                    }
                }
                .onDisappear {
                    isPulsating = false // resets the state so it can animate again next time!
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
    }
    
    private var handSizePicker: some View {
        VStack(spacing: 40) {
            Text("Hand Size:")
                .font(.system(size: isExpanded ? 30 : 20, weight: .semibold, design: .serif))
                .foregroundColor(.white)
            
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
        
        Image(imageName)
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
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    handSize = selectedHandSize
                }
            }
    }
}

// MARK: - Init & Helper structs/classes
class MenuViewModel: ObservableObject { //only tracks presentation style
    @Published var presentationStyle: MSMessagesAppPresentationStyle

    init(presentationStyle: MSMessagesAppPresentationStyle) {
        self.presentationStyle = presentationStyle
    }
}

struct MenuGame: Identifiable {
    let id = UUID()
    var type: GameType
    var title: String
    var logoCard: String // The front of the card
    var wins: Int = 0

    var localizedLogoCard: String {
        let isSimplifiedChinese = Locale.preferredLanguages.first?.hasPrefix("zh-Hans") == true
        return isSimplifiedChinese ? logoCard + "Chinese" : logoCard
    }
}
