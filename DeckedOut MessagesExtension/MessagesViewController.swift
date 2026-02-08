//
//  MessagesViewController.swift
//  DeckedOut MessagesExtension
//
//  Created by Sawyer Christensen on 6/19/25.
//

import UIKit
import Messages
import SwiftUI
import AVFoundation //for audio

class MessagesViewController: MSMessagesAppViewController {
    
    private var menuViewModel: MenuViewModel? //what keeps track of if the menu is compact/extended
    private var transcriptHeight: CGFloat = 200 //default fallback transcript live layout height. should never be 200. if it does, be suspicious...
    let gameManager = GameManager()//Le Game Engine
    
    // MARK: – View Life-Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupAudioSession()
        
        // Listen for turn completion
        gameManager.onTurnCompleted = { [weak self] gameState in
            self?.sendGameMove(gameState: gameState)
        }
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default) //.ambient allows mixing with background music and respects silent switch
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            //print("Could not set up audio session: \(error)")
        }
        _ = SoundManager.instance //this *should* load the sound manager into ram and trigger the lazy init
    }

    
    // MARK: - Conversation Handling
    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        guard let message = conversation.selectedMessage, // If there's no message to select, the user is likely opening the main menu from the app drawer
              let decodedState = extractState(from: message) else { return }
        
        let isFromMe = !conversation.remoteParticipantIdentifiers.contains(message.senderParticipantIdentifier)
        
        if presentationStyle == .transcript {
            presentTranscriptView(for: decodedState, isFromMe: isFromMe)
        } else {
            loadGameStateToMemory(from: message, conversation: conversation, isExplicitTap: true)
        }
    }
    
    override func contentSizeThatFits(_ size: CGSize) -> CGSize { //only triggers within a transcript view child of MSMessagesAppViewController
        return CGSize(width: size.width, height: transcriptHeight)
    }
    
    override func didResignActive(with conversation: MSConversation) {
        gameManager.saveMidTurnState(conversationID: conversation.localParticipantIdentifier.uuidString)
        super.didResignActive(with: conversation)
    }
    
    override func didSelect(_ message: MSMessage, conversation: MSConversation) {
        super.didSelect(message, conversation: conversation)
        loadGameStateToMemory(from: message, conversation: conversation, isExplicitTap: true) //is it actually always true here???
        presentGameView()
    }
   
    override func didReceive(_ message: MSMessage, conversation: MSConversation) {
        super.didReceive(message, conversation: conversation)
        loadGameStateToMemory(from: message, conversation: conversation, isExplicitTap: false)
    }
    
    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.willTransition(to: presentationStyle)
        guard let conversation = activeConversation else { return }
    
        let isGameLoaded = !gameManager.playerHand.isEmpty
        let isShowingMenu = children.first is UIHostingController<MainMenuView>
        let isShowingGame = children.first is UIHostingController<GinRootView>
        
        if !isGameLoaded && isShowingMenu { // Menu resizing
            withAnimation(.easeInOut(duration: 0.3)) {
                menuViewModel?.presentationStyle = presentationStyle }
            return
        }
        
        if presentationStyle == .expanded {
            if isGameLoaded {
                if !isShowingGame { // A game IS loaded but game isn't on screen yet -> Show it.
                    presentGameView()
                } else { // A game is loaded and is already on screen -> Do nothing! (to prevent erroneous view reinit
                    return
                }
            } else {  // Expanded, but no game loaded -> Show Menu
                presentMenuView(for: presentationStyle, with: conversation)
            }
        } else { // view is compact -> Always Menu
            presentMenuView(for: presentationStyle, with: conversation)
        }
    }
    
    // MARK: - Helper functions
    private func presentTranscriptView(for state: GameState, isFromMe: Bool) {
        let rootView = makeTranscriptView(for: state, isFromMe: isFromMe)
        let transcriptViewController = UIHostingController(rootView: rootView)
        presentView(transcriptViewController)
    }
    
    @ViewBuilder
    private func makeTranscriptView(for state: GameState, isFromMe: Bool) -> some View {
        if state.turnNumber == 0 {
            TranscriptInviteView(
                onHeightChange: { [weak self] height in
                    self?.transcriptHeight = height
                }
            )
            .onTapGesture {
                self.requestPresentationStyle(.expanded)
            }
        } else {
            TranscriptWaitingView(
                gameState: state,
                isFromMe: isFromMe,
                onHeightChange: { [weak self] height in
                    self?.transcriptHeight = height
                }
            )
            .onTapGesture {
                self.requestPresentationStyle(.expanded)
            }
        }
    }
    
    private func presentMenuView(for presentationStyle: MSMessagesAppPresentationStyle, with conversation: MSConversation) {
        let viewModel = MenuViewModel(presentationStyle: presentationStyle)
        self.menuViewModel = viewModel
        
        let menuView = MainMenuView(viewModel: viewModel) { [weak self] selectedSize in
            self?.createGame(conversation: conversation, handSize: selectedSize)
        }
                
        presentView(UIHostingController(rootView: menuView))
        requestPresentationStyle(.compact)
    }
    
    private func presentGameView() {
        //removeAllChildViewControllers()
        let gameRootView = GinRootView(game: self.gameManager)
        let gameViewController = UIHostingController(rootView: gameRootView)
        
        presentView(gameViewController)
        requestPresentationStyle(.expanded)
    }
    
    private func presentView(_ viewController: UIViewController) {
        //remove all existing child view controllers
        removeAllChildViewControllers()
        
        //add the new view controller
        self.addChild(viewController)
        viewController.view.frame = self.view.bounds
        viewController.view.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(viewController.view)
        
        NSLayoutConstraint.activate([
            viewController.view.topAnchor.constraint(equalTo: self.view.topAnchor),
            viewController.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            viewController.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            viewController.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor)
        ])
        
        viewController.didMove(toParent: self)
    }
    
    private func removeAllChildViewControllers() {
        for child in self.children {
            child.willMove(toParent: nil)
            child.view.removeFromSuperview()
            child.removeFromParent()
        }
    }
    
    private func createGame(conversation: MSConversation, handSize: Int) {
        let session = MSSession()
        let message = MSMessage(session: session)
        let templateLayout = MSMessageTemplateLayout()
        
        templateLayout.image = UIImage(named: "GinDefault")
        templateLayout.caption = NSLocalizedString("Let's Play Gin!", comment: "1st iMessage layout caption")
        message.layout = templateLayout
        message.summaryText = NSLocalizedString("Let's Play Gin!", comment: "1st iMessage summary text")
        
        let startingGameState = gameManager.createNewGameState(withHandSize: handSize)
        guard let jsonData = try? JSONEncoder().encode(startingGameState) else { return }
        let jsonString = jsonData.base64EncodedString()
        var components = URLComponents()
        components.queryItems = [URLQueryItem(name: "gameState", value: jsonString)]
        message.url = components.url
        
        let liveLayout = MSMessageLiveLayout(alternateLayout: templateLayout)
        message.layout = liveLayout
        
        requestPresentationStyle(.compact)
        
        conversation.insert(message) { error in //could change to send later!
            if let error = error {
                print("Error inserting message: \(error.localizedDescription)")
            }
        }
        
    }
    
    func sendGameMove(gameState: GameState) {
        guard let conversation = activeConversation else { return }
        guard let jsonData = try? JSONEncoder().encode(gameState) else { return }
        
        // Package the game state further
        let jsonString = jsonData.base64EncodedString()
        var components = URLComponents()
        components.queryItems = [URLQueryItem(name: "gameState", value: jsonString)]
        
        // Create the message & attach data
        let message = MSMessage(session: conversation.selectedMessage?.session ?? MSSession())
        message.url = components.url
        
        // Set basic template appearance
        let templateLayout = MSMessageTemplateLayout()
        if gameManager.playerHasWon {
            templateLayout.image = UIImage(named: "GinGameWon")
            templateLayout.caption = NSLocalizedString("I won in Gin!", comment: "")
        } else {
            templateLayout.image = UIImage(named: "GinDefault")
            templateLayout.caption = NSLocalizedString("Your turn in Gin!", comment: "iMessage layout caption")
            message.summaryText = NSLocalizedString("Gin", comment: "1st iMessage summary text") } //change this to the card they discarded
        
        let liveLayout = MSMessageLiveLayout(alternateLayout: templateLayout)
        message.layout = liveLayout
        
        gameManager.clearMidTurnState(conversationID: conversation.localParticipantIdentifier.uuidString)
        
        // ...aaaand send!
        conversation.send(message) { error in
            if let error = error { print(error) }
        }
    }
    
    private func extractState(from message: MSMessage) -> GameState? {
        guard let url = message.url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let stateString = components.queryItems?.first(where: { $0.name == "gameState" })?.value,
              let stateData = Data(base64Encoded: stateString) else { return nil }
        
        return try? JSONDecoder().decode(GameState.self, from: stateData)
    }
    
    private func loadGameStateToMemory(from message: MSMessage, conversation: MSConversation, isExplicitTap: Bool) {
        guard let decodedState = extractState(from: message) else { return }
        
        let senderID = message.senderParticipantIdentifier
        let isFromMe = !conversation.remoteParticipantIdentifiers.contains(senderID)
        gameManager.loadState(
            decodedState,
            isPlayersTurn: !isFromMe,
            isExplicitTap: isExplicitTap,
            conversationID: conversation.localParticipantIdentifier.uuidString)
    }
}

