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
    
    var onStartGame: (Int) -> Void //triggers createGame in MessagesViewController
    
    @State private var handSize = 7 //full game is normally 10, but 7 is quicker and better suited for mobile
    @State private var cardsAnimatedAway = 0
    @State private var hiddenAnimatedAwayCards = 0
    @State private var isPulsating = false //for the "state game" text
    @State private var card7Image: String = ""
    @State private var card10Image: String = ""
    let suits = ["Hearts", "Diamonds", "Clubs", "Spades"]
    
    @State private var titleTransitionEdge: Edge = .trailing
    @State private var activeGameIndex: Int = 0
    @State private var availableGames: [MenuGame] = [
        MenuGame(title: "Gin Rummy", logoCard: "ginRummyCard"),
        MenuGame(title: "Crazy 8s", logoCard: "crazy8sCard"),
        MenuGame(title: "Golf", logoCard: "golfCard"),
        MenuGame(title: "Spades", logoCard: "spadesCard")
    ]
    @State private var isInSubview: Bool = false
    @State private var isTitleBarHidden: Bool = false
  
    
    var body: some View {
        ZStack {
            if isInSubview {
                Group {
                    if viewModel.presentationStyle == .expanded {
                        expandedLayout
                    } else {
                        compactLayout
                    }
                }
                //.overlay(backButton, alignment: .topLeading)
                .transition(.move(edge: .bottom))//.combined(with: .opacity))
            }
            
            // MAIN MENU
            VStack {
                gameTitleBar
                    .opacity(isTitleBarHidden ? 0 : 1)
                
                Spacer()
                Spacer()
                
                MenuCardWheel(
                    games: availableGames,
                    onActiveIndexChange: { newIndex in // handle real-time mid-swipe updates
                        if activeGameIndex != newIndex {
                            titleTransitionEdge = newIndex > activeGameIndex ? .trailing : .leading
                            withAnimation(.easeInOut(duration: 0.2)) {
                                activeGameIndex = newIndex
                            }
                        }
                    },
                    userSelectedGame: { index in // handle selecting a game
                        print("Open Game: \(availableGames[index].title)") //replace this with a meaninful subview call
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isInSubview = true
                        }
                        withAnimation(.linear(duration: 0.05).delay(0.15)) { //wait a bit then trigger a fast fade
                            isTitleBarHidden = true
                        }
                    },
                    hasSelectedGame: $isInSubview
                )
                //.zIndex(999) //keep the cards on top
                .frame(maxWidth: UIScreen.main.bounds.width) //dont let them expand the zstack when they fan out
                .offset(y: 50)
            }
        }
        //.animation(.easeInOut, value: isInSubview)
        .background(backgroundLayer) //THIS DOES NOT MESS IT UP
        .onAppear {
            preloadWins()
        }
    }
    
    private var backgroundLayer: some View {
        ZStack {
            Image(colorScheme == .dark ? "feltBackgroundDark" : "feltBackgroundLight")
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
        VStack(spacing: 4) {
            Text(availableGames[activeGameIndex].title)
                //.font(.system(size: 20, weight: .semibold, design: .serif))
                .font(.title)
                .fontWeight(.semibold)
                .fontDesign(.serif)
                .foregroundColor(.primary)
                .shadow(radius: 5)
                .id(activeGameIndex)
                .transition(.asymmetric(
                    insertion: .move(edge: titleTransitionEdge).combined(with: .opacity),
                    removal: .move(edge: titleTransitionEdge == .trailing ? .leading : .trailing).combined(with: .opacity)
                ))
                .animation(.easeInOut, value: activeGameIndex)
            
            HStack(spacing: 4) { // Adjust spacing to move the crown closer/further from the text
                Image(systemName: "crown.fill")
                    .foregroundStyle(LinearGradient(colors: [
                        Color(red: 1.0, green: 1.0, blue: 0.33), // Bright Yellow at the top
                            Color(red: 1.0, green: 0.7, blue: 0.3) // Orangish/gold at the bottom
                        ],
                        startPoint: .top, // or topLeading
                        endPoint: .bottom // & bottomTrailing
                    ))
                    .shadow(color: .orange, radius: 3)
                
                Text("\(availableGames[activeGameIndex].wins) Wins")
            }
            .font(.subheadline)
            .fontWeight(.medium)
            
    
            Divider()
                .opacity(0)
            
            Divider()
                .opacity(0)
            
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(uiColor: .systemBackground).opacity(1.0),
                    //Color.black.opacity(0.5),
                    Color(uiColor: .systemBackground).opacity(0.0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
    
    
    // MARK: - Menu helper functins
    private func preloadWins() {
        for index in availableGames.indices {
            let title = availableGames[index].title
            availableGames[index].wins = WinTracker.shared.getWinCount(for: title)
        }
    }
    
    // MARK: - Legacy Presentation styles
    private var compactLayout: some View {
        ZStack(alignment: .topLeading) {
            backButton
                .padding(.leading, 14)
                
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
    
    private var expandedLayout: some View {
        VStack {
            Spacer()
            startButton
            Spacer()
            deckSection
            Spacer()
            handSizePicker
            Spacer()
        }
    }
    
    
    // MARK: - Layout Components
    private var backButton: some View {
        Button(action: {
            // Reverse the animations
            withAnimation(.easeInOut(duration: 0.2)) {
                isInSubview = false
            }
            withAnimation(.linear(duration: 0.05).delay(0.1)) { // Bring the title back
                isTitleBarHidden = false
            }
            Task {
                try? await Task.sleep(nanoseconds: 200_000_000)
                cardsAnimatedAway = 0
            }
        }) {
            Image(systemName: "chevron.left")
                .font(.title3.weight(.bold))
                .foregroundColor(.primary)
                .padding(14)
                .background(.ultraThinMaterial, in: Circle()) // Liquid glass effect!
                .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 2)
        }
        .padding(.leading, 14)
        //.padding(.top, 20)
    }
    
    private var deckSection: some View {
        ZStack {
            let winCount = WinTracker.shared.getWinCount(for: availableGames[activeGameIndex].title)
            if winCount == 0 {
                Text("Wins: \(winCount)\n\nGood luck!")
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .opacity(cardsAnimatedAway > 5 ? 1 : 0)
            } else {
                Text("Wins: \(winCount)")
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundColor(.white)
                    .opacity(cardsAnimatedAway > 5 ? 1 : 0)
            }
            
            let isIpad = UIDevice.current.userInterfaceIdiom == .pad
            ForEach(0..<5) { i in
                Image("cardBackRed")
                    .resizable()
                    .aspectRatio(0.7, contentMode: .fit)
                    .frame(height: viewModel.presentationStyle == .expanded ? 200 : 145) // Make cards bigger in expanded!
                    .rotationEffect(i >= 5 - cardsAnimatedAway ? Angle(degrees: 45) : Angle(degrees: 0))
                    .offset(x: i >= 5 - cardsAnimatedAway ? (isIpad ? 400 : 225) : CGFloat(-i) * 3,
                            y: i >= 5 - cardsAnimatedAway ? (isIpad ? 300 : -450) : CGFloat(-i) * 3)
                    .shadow(radius: i == 4 ? 1 : 8)
                    .opacity(i >= 5 - hiddenAnimatedAwayCards ? 0 : 1)
            }
        }
    }
    
    private var startButton: some View {
        Button(action: {
            DispatchQueue.global(qos: .userInitiated).async {
                onStartGame(handSize)
                DispatchQueue.main.async {
                    withAnimation(.spring(duration: 0.7)) {
                        cardsAnimatedAway += 1
                    }
                    if cardsAnimatedAway <= 5 {
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
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundColor(.white)
                .scaleEffect(isPulsating ? 1.03 : 1)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                        isPulsating = true
                    }
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
        .buttonStyle(PlainButtonStyle())
    }
    
    private var handSizePicker: some View {
        VStack(spacing: 40) {
            Text("Hand Size:")
                .font(.system(size: 20, weight: .semibold, design: .serif))
                .foregroundColor(.white)
            
            HStack(spacing: 30) {
                if !card7Image.isEmpty && !card10Image.isEmpty {
                    cardOption(selectedHandSize: 7, imageName: card7Image, tilt: -8) //left card
                    cardOption(selectedHandSize: 10, imageName: card10Image, tilt: 8) //right card
                }
            }
        }
        .onAppear {
            card7Image = "7\(suits.randomElement() ?? "Spades")"
            card10Image = "10\(suits.randomElement() ?? "Clubs")"
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

class MenuViewModel: ObservableObject { //only tracks presentation style
    @Published var presentationStyle: MSMessagesAppPresentationStyle

    init(presentationStyle: MSMessagesAppPresentationStyle) {
        self.presentationStyle = presentationStyle
    }
}

struct MenuGame: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let logoCard: String // The front of the card
    var wins: Int = 0
}

class WinTracker {
    static let shared = WinTracker()
    private let legacyGinKey = "ginWins" // <- set for deprecation on a later update
    
    private func key(for gameTitle: String) -> String {
        return "\(gameTitle.lowercased().replacingOccurrences(of: " ", with: "_"))_wins"
    }

    func getWinCount(for gameTitle: String) -> Int {
        //MIGRATING OLD GIN WIN KEY TO NEW GIN WIN KEY
        let newKey = key(for: gameTitle)
        let defaults = UserDefaults.standard
        if gameTitle == "Gin Rummy" && defaults.object(forKey: newKey) == nil {
            let legacyWins = defaults.integer(forKey: legacyGinKey)
            if legacyWins > 0 {
                // Move the data to the new key
                defaults.set(legacyWins, forKey: newKey)
                // Remove the old key so we don't migrate again
                defaults.removeObject(forKey: legacyGinKey)
                return legacyWins
            }
        }
        
        return UserDefaults.standard.integer(forKey: key(for: gameTitle)) //after migration replace with "return UserDefaults.standard.integer(forKey: key(for: gameTitle))"
    }
    
    func incrementWins(for gameTitle: String) {
        let currentWins = getWinCount(for: gameTitle)
        UserDefaults.standard.set(currentWins + 1, forKey: key(for: gameTitle))
    }
}
