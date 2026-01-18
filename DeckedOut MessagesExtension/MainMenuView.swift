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
    @Environment(\.locale) var locale //for language detection
    @ObservedObject var viewModel: MenuViewModel
    var onStartGame: (Int) -> Void //triggers createGame in MessagesViewController
    //can add win counts?
    @State private var cardsAnimatedAway = 0
    
    @State private var card7Image: String = ""
    @State private var card10Image: String = ""
    let suits = ["Hearts", "Diamonds", "Clubs", "Spades"]
    
    @State private var handSize = 7 //full game is normally 10, but 7 is quicker and better suited for mobile
    
    var body: some View {
        ZStack {
            // Shared Background (Felt & Shading)
            Image("feltBackground")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
            
            LinearGradient(
                gradient: Gradient(colors: [Color.white.opacity(0.1), Color.black.opacity(0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Layout based on current presentation style
            if viewModel.presentationStyle == .expanded {
                expandedLayout
            } else {
                compactLayout
            }
        }
    }
    
    // MARK: - Presentation styles
    private var compactLayout: some View {
        HStack {
            Spacer()
            deckSection
            Spacer()
            VStack(spacing: 20) {
                startButton
                handSizePicker
            }
            //Spacer()
            .padding(.trailing, 10)
        }
    }
    
    private var expandedLayout: some View {
        VStack {
            Spacer()
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
    private var deckSection: some View {
        ZStack {
            let winCount = WinTracker.shared.getWinCount()
            if winCount == 0 {
                Text("Wins: \(winCount)\n\nBetter start!")
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
            
            ForEach(0..<5) { i in
                Image("cardBackRed")
                    .resizable()
                    .aspectRatio(0.7, contentMode: .fit)
                    .frame(height: viewModel.presentationStyle == .expanded ? 200 : 145) // Make cards bigger in expanded!
                    .rotationEffect(i >= 5 - cardsAnimatedAway ? Angle(degrees: 45) : Angle(degrees: 0))
                    .offset(x: i >= 5 - cardsAnimatedAway ? 225 : CGFloat(-i) * 3,
                            y: i >= 5 - cardsAnimatedAway ? -450 : CGFloat(-i) * 3)
                    .shadow(radius: i == 4 ? 1 : 8)
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
                }
            }
        }) {
            Text("Start Game!")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 15).fill(Color.black.opacity(0.3)).offset(y: 4) //depth layer
                        RoundedRectangle(cornerRadius: 15).fill(LinearGradient(colors: [Color(white: 0.3), Color(white: 0.1)], startPoint: .top, endPoint: .bottom)) //main button body
                    }
                )
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.2), lineWidth: 2))
                .shadow(color: .white.opacity(0.1), radius: 15)
        }
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

class WinTracker {
    static let shared = WinTracker()
    private let winsKey = "ginWins"

    func getWinCount() -> Int {
        return UserDefaults.standard.integer(forKey: winsKey)
    }
    
    func incrementWins() {
        var currentWins = getWinCount()
        currentWins += 1
        UserDefaults.standard.set(currentWins, forKey: winsKey)
    }
}
