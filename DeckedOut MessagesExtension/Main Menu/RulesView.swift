//
//  RulesView.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 2/19/26.
//

import SwiftUI

struct RulesView: View {
    let gameType: GameType
    var isExpanded: Bool = false
    var onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            // Dimmed tappable background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }
            
            // Rules card
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, isExpanded ? 20 : 12)
                //.padding(.bottom, 12)
                
                // Paged rule pages
                TabView {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        RulePage(
                            imageName: page.image,
                            title: page.title,
                            description: page.description,
                            pageNumber: index + 1,
                            totalPages: pages.count,
                            isExpanded: isExpanded
                        )
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }
            .frame(maxWidth: .infinity, maxHeight: 350)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.5), .white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: .black.opacity(0.25), radius: 30, x: 5, y: 15)
            .padding(.horizontal, 24)
        }
    }
    
    // MARK: - Per-game content
    private var title: String {
        switch gameType {
        case .ginRummy: return "Gin Rummy Rules"
        case .crazy8s:  return "Crazy 8s Rules"
        case .golf:     return "Golf Rules"
        case .unknown:  return "Rules"
        }
    }
    
    private var pages: [(image: String, title: String, description: String)] {
        switch gameType {
        case .ginRummy:
            return [
                ("rectangle.stack", "The Deal", "Each player is dealt a hand of cards. The remaining cards form the draw pile, and the top card starts the discard pile."),
                ("arrow.2.circlepath", "Your Turn", "Draw one card from either the deck or the discard pile, then discard one card from your hand."),
                ("rectangle.3.group", "Melds", "Arrange your cards into sets (same rank) or runs (consecutive cards of the same suit) of 3 or more."),
                ("crown.fill", "How to Win", "Once all your cards form valid melds, you win! The fewer turns it takes, the better.")
            ]
        case .crazy8s:
            return [
                ("rectangle.stack", "The Deal", "Each player is dealt a hand of cards. The remaining cards form the draw pile, and the top card starts the discard pile."),
                ("arrow.2.circlepath", "Your Turn", "Discard a card that matches the top discard's rank or suit. If you can't, draw from the deck. If you draw three cards and still can't discard, your turn is skipped."),
                ("8.circle.fill", "Crazy 8s!", "Eights are wild! Play an 8 at any time and choose the suit for the next player to follow."),
                ("crown.fill", "How to Win", "Be the first player to get rid of all your cards!")
            ]
        case .golf:
            return [
                ("figure.golf", "Coming Soon", "Golf rules will be added when the game is available.")
            ]
        /*case .spades:
            return [
                ("suit.spade.fill", "Coming Soon", "Spades rules will be added when the game is available.")
            ]*/
        case .unknown:
            return [
                ("questionmark", "Unknown Game", "No rules available for this game.")
            ]
        }
    }
}

// MARK: - Rule Page
private struct RulePage: View {
    var imageName: String
    var title: String
    var description: String
    var pageNumber: Int
    var totalPages: Int
    var isExpanded: Bool = false
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1.0 //padding needs to shrink as text size increases. iOS does not do this automatically
    
    var body: some View {
        VStack(spacing: 12 / pow(scale, 3)) {
            Image(systemName: imageName)
                .resizable()
                .scaledToFit()
                .frame(height: 50)
                .foregroundStyle(.white.opacity(0.85))
                .shadow(color: .white.opacity(0.3), radius: 3)
                .padding(.top, (isExpanded ? 24 : 8) / pow(scale, 3))
            
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(description)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24 / pow(scale, 2))
            
            Spacer()
        }
        .padding(.top, 12 / pow(scale, 3))
    }
}
