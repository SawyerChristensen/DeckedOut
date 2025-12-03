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
    var onStartGame: () -> Void
    //can add win count icons per game later...
    
    var body: some View {
        
        Spacer()
        
        Button(action: {
            onStartGame()
        }) {
            Text("Start Game!")
        }
        
        Spacer()
    }
}

class MenuViewModel: ObservableObject { //only tracks presentation style
    @Published var presentationStyle: MSMessagesAppPresentationStyle

    init(presentationStyle: MSMessagesAppPresentationStyle) {
        self.presentationStyle = presentationStyle
    }
}
