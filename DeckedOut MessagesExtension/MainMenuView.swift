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
        
        HStack {
            
            Spacer()
            
            VStack { // 1st Column
                Spacer()
                
                ZStack { // Deck
                    ForEach(0..<5) { i in
                        Image("cardBackRed")
                            .resizable()
                            .aspectRatio(0.7, contentMode: .fit)
                            .frame(height: 145)
                            .rotationEffect(i >= 5 - cardsAnimatedAway ? Angle(degrees: 45) : Angle(degrees: 0))
                            .offset(x: i >= 5 - cardsAnimatedAway ? 200 : CGFloat(-i) * 3,
                                    y: i >= 5 - cardsAnimatedAway ? -400 : CGFloat(-i) * 3)
                        //.rotationEffect(i >= 5 - cardsAnimatedAway ? Angle(degrees: -180) : Angle(degrees: 0))
                            .opacity(i >= 5 - cardsAnimatedAway ? 0 : 1)
                            .shadow(radius: i == 4 ? 1 : 8)
                    }
                    
                    Text("Maybe try sending \nthe message? ↗️") //an easter egg!
                        .font(.system(size: 14, weight: .bold, design: .serif))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .opacity(cardsAnimatedAway > 5 ? 1 : 0)
                }
                
                Spacer()
            }
            
            Spacer()
            
            VStack { // 2nd Column
                Spacer()
                
                Button(action: {
                    // game logic in the background
                    DispatchQueue.global(qos: .userInitiated).async {
                        onStartGame(handSize)
                        
                        // main thread for UI/Sound updates
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
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            ZStack {
                                // Depth Layer
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(Color.black.opacity(0.3))
                                    .offset(y: 4)
                                
                                // Main Button Body
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(LinearGradient(colors: [Color(white: 0.3), Color(white: 0.1)], startPoint: .top, endPoint: .bottom))
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.white.opacity(0.2), lineWidth: 2)
                        )
                        .shadow(color: .white.opacity(0.1), radius: 15)
                }
                
                Spacer()
                
                VStack(spacing: 40) {
                    Text("Hand Size:")
                        .font(.system(size: 20, weight: .semibold, design: .serif))
                        .foregroundColor(.white)
                        //.underline()
                    
                    HStack(spacing: 30) {
                        if !card7Image.isEmpty && !card10Image.isEmpty {
                            cardOption(selectedHandSize: 7, imageName: card7Image, tilt: -8) //left hand
                            cardOption(selectedHandSize: 10, imageName: card10Image, tilt: 8) //right card
                        }
                    }
                    .onAppear {
                        card7Image = "7\(suits.randomElement() ?? "Spades")"
                        card10Image = "10\(suits.randomElement() ?? "Clubs")"
                    }
                }
                
            }
            .padding(.trailing, 10)
        }
        .background( //shading
            /*RadialGradient( //a vignette
                gradient: Gradient(colors: [.white.opacity(0.05), .black.opacity(0.1)]),
                center: .center,
                startRadius: 150, // The "clear" center area
                endRadius: 300   // Where the darkness reaches its peak
            )*/
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0.1), // "Light source" at top-left
                    Color.black.opacity(0.1)  // "Shadow" at bottom-right
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .background(Image("feltBackground"))
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
