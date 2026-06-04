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
    
    @ObservedObject private var cardBackSelection = CardBackSelection.shared
    @State private var currentPage: Int = 0
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1.0 //padding needs to shrink as text size increases. iOS does not do this automatically
    
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
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Close", comment: "VoiceOver accessibility label for the rules window close button"))
                    .accessibilityHint(Text("Closes the rules window", comment: "VoiceOver accessibility hint describing what the rules close button does"))
                    .accessibilityInputLabels([
                        Text("Close rules", comment: "Voice Control input label"),
                        Text("Dismiss", comment: "Voice Control input label"),
                        Text("Dismiss rules", comment: "Voice Control input label"),
                        Text("Exit", comment: "Voice Control input label"),
                        Text("Exit rules", comment: "Voice Control input label")
                    ])
                }
                .padding(.horizontal, 20)
                .padding(.top, isExpanded ? 20 : 12)
                
                // The SF Symbol Icon
                if !pages.isEmpty {
                    pages[currentPage].symbol.image
                        .font(.system(size: 45))
                        .frame(width: 50, height: 50)
                        .foregroundStyle(
                            .white,                              // Primary (Layer 1)
                            cardBackSelection.selectedColor,     // Secondary (Layer 2) — matches equipped theme
                            .black                               // Tertiary (Layer 3)
                        )
                        .applyGradientSymbolColor()
                        //.shadow(color: .white.opacity(0.3), radius: 3)
                        .padding(.top, (isExpanded ? 24 : 12) / pow(scale, 3))
                        .contentTransition(.symbolEffect(.replace))
                }
                
                // Paged rule pages
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        RulePage(
                            //imageName: page.image,
                            title: page.title,
                            description: page.description,
                            pageNumber: index + 1,
                            totalPages: pages.count,
                            isExpanded: isExpanded
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }
            .frame(maxWidth: 350, maxHeight: 350) //used to be inifinite width but we have to limit for ipad
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
    private var title: LocalizedStringKey {
        switch gameType {
        case .ginRummy: return "Gin Rummy Rules"
        case .crazy8s:  return "Crazy 8s Rules"
        case .golf:     return "Golf Rules"
        case .unknown:  return "Rules"
        }
    }
    
    private var pages: [(symbol: SymbolType, title: LocalizedStringKey, description: LocalizedStringKey)] {
        switch gameType {
        case .ginRummy:
            return [
                (.custom("colored.square.stack.3d.up"), "The Deal", "Each player is dealt a hand of cards. The remaining cards form the draw pile, and the top card starts the discard pile."),
                (.system("arrow.trianglehead.2.clockwise.rotate.90"), "Your Turn", "Draw one card from either the deck or the discard pile, then discard one card from your hand."),
                (.custom("colored.rectangle.3.group"), "Melds", "Arrange your cards into sets (same rank) or runs (consecutive cards of the same suit) of 3 or more."),
                (.system("crown.fill"), "How to Win", "Once all your cards form valid melds, you win! The fewer turns it takes, the better.")
            ]
        case .crazy8s:
            return [
                (.custom("colored.square.stack.3d.up"), "The Deal", "Each player is dealt a hand of cards. The remaining cards form the draw pile, and the top card starts the discard pile."),
                (.system("arrow.trianglehead.2.clockwise.rotate.90"), "Your Turn", "Discard a card that matches the discard's rank or suit. If you can't, draw from the deck. If you draw three cards and still can't discard, your turn is skipped."),
                (.system("8.circle.fill"), "Crazy 8s!", "Eights are wild! Twos make the next opponent draw two, Queens skip, Aces reverse the direction of play."),
                (.system("crown.fill"), "How to Win", "Be the first player to get rid of all of your cards!")
            ]
        case .golf:
            return [
                (.custom("colored.rectangle.grid.3x2"), "The Layout", "Each player gets 6 cards arranged in a grid. Most start face down, with 2 cards randomly revealed."),
                (.system("arrow.trianglehead.2.clockwise.rotate.90"), "Your Turn", "Draw a card from the deck or the discard pile, then swap it with any card in your grid. The swapped card is discarded."),
                (.system("figure.golf"), "Scoring", "Aces are 1 point, number cards are face value, Jacks and Queens are 10, and Kings are 0. Matching pairs in the same column cancel out!"),
                (.system("crown.fill"), "How to Win", "The player with the lowest total score wins. If there is a tie, the player who went out first loses.")
            ]
        case .unknown:
            return [
                (.system("questionmark"), "Unknown Game", "No rules available for this game.")
            ]
        }
    }
}

// MARK: - Rule Page
private struct RulePage: View {
    //var imageName: String
    var title: LocalizedStringKey
    var description: LocalizedStringKey
    var pageNumber: Int
    var totalPages: Int
    var isExpanded: Bool = false
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1.0 //padding needs to shrink as text size increases. iOS does not do this automatically
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12 / pow(scale, 3)) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.top, 8 / pow(scale, 3))

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24 / pow(scale, 2))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8 / pow(scale, 3))
        }
        .scrollIndicators(.automatic)
        .scrollBounceBehavior(.basedOnSize)
    }
}

enum SymbolType {
    case system(String)
    case custom(String)
    
    var image: Image {
        switch self {
        case .system(let name):
            return Image(systemName: name)
        case .custom(let name):
            return Image(name)
        }
    }
}

extension View {
    @ViewBuilder
    func applyGradientSymbolColor() -> some View {
        if #available(iOS 26.0, *) {
            self.symbolColorRenderingMode(.gradient)
        } else {
            self // Returns the view without the modifier on older versions
        }
    }
}
