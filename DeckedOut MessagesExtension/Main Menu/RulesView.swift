//
//  GinRules.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 2/19/26.
//
/*
struct RulesView: View {
    var body: some View {
        TabView {
            // PAGE 1: Setup
            RulePage(
                imageName: "cards.playingcard.stack", // Or your own asset
                title: "The Setup",
                description: "Each player is dealt 7 cards. The remaining cards form the draw pile."
            )
            
            // PAGE 2: Gameplay
            RulePage(
                imageName: "arrow.2.circlepath",
                title: "On Your Turn",
                description: "Draw one card from the deck or the discard pile, then discard one card."
            )
            
            // PAGE 3: Winning
            RulePage(
                imageName: "crown.fill",
                title: "How to Win",
                description: "Form valid sets and runs until all your cards are matched."
            )
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always)) // Gives the dots a nice background
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

struct RulePage: View {
    var imageName: String
    var title: String
    var description: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: imageName)
                .resizable()
                .scaledToFit()
                .frame(height: 120)
                .foregroundColor(.blue)
            
            Text(title)
                .font(.title)
                .fontWeight(.bold)
            
            Text(description)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            
            Spacer()
        }
        .padding(.top, 50)
    }
}
*/
