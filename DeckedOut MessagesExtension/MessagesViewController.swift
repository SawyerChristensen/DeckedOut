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
    private var activeGameEngine: GameEngine?
    
    // MARK: – View Life-Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupAudioSession()
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
        guard let message = conversation.selectedMessage, // Do we have a message? Can we decode it?
            let gameInfo = extractGameInfo(from: message) else { return } // If there's no message to select, the user is likely opening the main menu from the app drawer
        
        let isFromMe = !conversation.remoteParticipantIdentifiers.contains(message.senderParticipantIdentifier)
        
        if presentationStyle == .transcript {
            print(gameInfo.data)
            presentTranscriptView(for: gameInfo.type, stateData: gameInfo.data, isFromMe: isFromMe)
        } else {
            loadGameStateToMemory(from: message, conversation: conversation)
        }
    }
    
    override func contentSizeThatFits(_ size: CGSize) -> CGSize { //only triggers within a transcript view child of MSMessagesAppViewController
        return CGSize(width: size.width, height: transcriptHeight)
    }
    
    override func willResignActive(with conversation: MSConversation) { //immediate closing changes
        SoundManager.instance.stopBackgroundMusic()
        super.willResignActive(with: conversation)
    }
    
    override func didResignActive(with conversation: MSConversation) { //after closing animation
        activeGameEngine?.saveMidTurnState(conversationID: conversation.localParticipantIdentifier.uuidString)
        super.didResignActive(with: conversation)
    }
    
    override func didSelect(_ message: MSMessage, conversation: MSConversation) {
        super.didSelect(message, conversation: conversation)
        loadGameStateToMemory(from: message, conversation: conversation)
        presentGameView()
    }
   
    override func didReceive(_ message: MSMessage, conversation: MSConversation) {
        super.didReceive(message, conversation: conversation)
        loadGameStateToMemory(from: message, conversation: conversation)
    }
    
    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.willTransition(to: presentationStyle)
        guard let conversation = activeConversation else { return }
    
        let isGameLoaded = !(activeGameEngine?.playerHand.isEmpty ?? true)
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
                } else { // A game is already loaded, but we may be opening a new session. load just in case
                    if let selectedMessage = conversation.selectedMessage {
                        loadGameStateToMemory(from: selectedMessage, conversation: conversation, isExplicitChange: true)
                    }
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
    private func presentTranscriptView(for gameType: GameType, stateData: Data, isFromMe: Bool) {
        let rootView = decideTranscriptView(for: gameType, stateData: stateData, isFromMe: isFromMe)
        let transcriptViewController = UIHostingController(rootView: rootView)
        presentView(transcriptViewController)
    }
    
    @ViewBuilder
    private func decideTranscriptView(for gameType: GameType?, stateData: Data, isFromMe: Bool) -> some View {
        switch gameType {
        case .ginRummy, .none:
            if let decodedState = try? JSONDecoder().decode(GinRummyGameState.self, from: stateData) {
                if decodedState.turnNumber == 0 { // Game invite
                    GinTranscriptInvite(
                        onHeightChange: { [weak self] height in
                            self?.transcriptHeight = height
                        }
                    )
                    .onTapGesture {
                        self.requestPresentationStyle(.expanded)
                    }
                } else { // Default waiting view the user will see in all cases except an invite
                    GinTranscriptWaiting(
                        gameState: decodedState,
                        isFromMe: isFromMe,
                        onHeightChange: { [weak self] height in
                            self?.transcriptHeight = height
                        }
                    )
                    .onTapGesture {
                        self.requestPresentationStyle(.expanded)
                    }
                }
            } else {
                Text("Error loading match data.") // Fallback UI in case the data is corrupted or decoding fails (should never trigger)
                    .padding()
            }
            
        case .crazy8s:
            if let decodedState = try? JSONDecoder().decode(Crazy8sGameState.self, from: stateData) {
                if decodedState.turnNumber == 0 { // Game invite
                    Crazy8sTranscriptInvite(
                        onHeightChange: { [weak self] height in
                            self?.transcriptHeight = height
                        }
                    )
                    .onTapGesture {
                        self.requestPresentationStyle(.expanded)
                    }
                } else { // Default waiting view the user will see in all cases except an invite
                    Crazy8sTranscriptWaiting(
                        gameState: decodedState,
                        isFromMe: isFromMe,
                        onHeightChange: { [weak self] height in
                            self?.transcriptHeight = height
                        }
                    )
                    .onTapGesture {
                        self.requestPresentationStyle(.expanded)
                    }
                }
            } else {
                // Fallback UI in case the data is corrupted or decoding fails
                Text("Error loading match data.") //should never trigger!
                    .padding()
            }
            
            
            
        case .golf:
            Text("Golf Transcript View")
        case .spades:
            Text("Spades Transcript View")
        case .some(_):
            // Catch-all for any future games you add to the enum but forget to add to this switch
            Text("Game unsupported: Update your app to play!")
        }
    }
    
    private func presentMenuView(for presentationStyle: MSMessagesAppPresentationStyle, with conversation: MSConversation) {
        let viewModel = MenuViewModel(presentationStyle: presentationStyle)
        self.menuViewModel = viewModel
        
        let menuView = MainMenuView(viewModel: viewModel) { [weak self] gameType, selectedSize in
            self?.createGame(conversation: conversation, gameType: gameType, handSize: selectedSize)
        }
                
        presentView(UIHostingController(rootView: menuView))
        requestPresentationStyle(.compact)
        SoundManager.instance.stopBackgroundMusic()
    }
    
    private func presentGameView() {
        guard let engine = activeGameEngine else { return }
        let gameViewController: UIViewController
        
        if let ginManager = engine as? GinRummyManager {
            if self.children.first is UIHostingController<GinRootView> { return }
            gameViewController = UIHostingController(rootView: GinRootView(game: ginManager))
            
        } else if let crazy8sManager = engine as? Crazy8sManager {
            if self.children.first is UIHostingController<Crazy8sRootView> { return }
            gameViewController = UIHostingController(rootView: Crazy8sRootView(game: crazy8sManager))
            
        } else {
            return
        }
        
        presentView(gameViewController)
        requestPresentationStyle(.expanded)
        SoundManager.instance.startBackgroundMusic()
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
    
    private func createGame(conversation: MSConversation, gameType: GameType, handSize: Int) {
        let session = MSSession()
        let message = MSMessage(session: session)
        let templateLayout = MSMessageTemplateLayout()
        
        //define template loadout view for non-iOS or iPadOS devices (macOS, visionOS, etc)
        switch gameType {
        case .ginRummy:
            self.activeGameEngine = GinRummyManager.shared
            templateLayout.image = UIImage(named: "GinDefault")
            templateLayout.caption = NSLocalizedString("Let's Play Gin!", comment: "1st iMessage layout caption")
        case .crazy8s:
            self.activeGameEngine = Crazy8sManager.shared
            templateLayout.image = UIImage(named: "CardGamesDefault")
            templateLayout.caption = "Let's Play Crazy 8s!"
        case .golf:
            // self.activeGameEngine = GolfManager.shared
            templateLayout.image = UIImage(named: "CardGamesDefault")
            templateLayout.caption = "Let's Play Golf!"
        case .spades:
            // self.activeGameEngine = SpadesManager.shared
            templateLayout.image = UIImage(named: "CardGamesDefault")
            templateLayout.caption = "Let's Play Spades!"
        }
        
        setupEngineListener()
        
        message.layout = templateLayout
        message.summaryText = templateLayout.caption
        
        //init and package initital game state
        guard let stateData = activeGameEngine?.createNewGameState(withHandSize: handSize) else {
            print("Error: Could not generate starting game state for \(gameType)")
            return
        }
        let jsonString = stateData.base64EncodedString()
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "gameType", value: gameType.rawValue),
            URLQueryItem(name: "gameState", value: jsonString)]
        message.url = components.url
        
        //set the template view as the backup to our live layout transcript view
        let liveLayout = MSMessageLiveLayout(alternateLayout: templateLayout)
        message.layout = liveLayout
        
        requestPresentationStyle(.compact)
        
        conversation.insert(message) { error in //could change to send later(?)!
            if let error = error {
                print("Error inserting message: \(error.localizedDescription)")
            }
        }
        
    }
    
    func sendGameMove(gameType: GameType, stateData: Data) {
        guard let conversation = activeConversation else { return }
        
        // Further package the game state
        let jsonString = stateData.base64EncodedString()
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "gameType", value: jsonString),
            URLQueryItem(name: "gameState", value: jsonString)]
        
        // Create the message & attach data
        let message = MSMessage(session: conversation.selectedMessage?.session ?? MSSession())
        message.url = components.url
        
        // Set basic template appearance
        let templateLayout = MSMessageTemplateLayout()
        
        if activeGameEngine?.playerHasWon == true {
            // Dynamically set the win image and caption based on the game being played
            switch gameType {
            case .ginRummy:
                templateLayout.image = UIImage(named: "GinGameWon")
                templateLayout.caption = NSLocalizedString("I won in Gin!", comment: "iMessage layout win caption")
                message.summaryText = NSLocalizedString("I won in Gin!", comment: "iMessage win message summary")
            case .crazy8s:
                templateLayout.image = UIImage(named: "CardGameWon")
                templateLayout.caption = "I won in Crazy 8s!"
                message.summaryText = "I won in Crazy 8s!"
            case .golf:
                templateLayout.image = UIImage(named: "CardGameWon")
                templateLayout.caption = "I won in Golf!"
                message.summaryText = "I won in Golf!"
            case .spades:
                templateLayout.image = UIImage(named: "CardGameWon")
                templateLayout.caption = "I won in Spades!"
                message.summaryText = "I won in Spades!"
            }
        } else {
            if let discardedCard = activeGameEngine?.discardPile.last {
                message.summaryText = String(localized: "Discarded \(discardedCard.rank.localizedName) of \(discardedCard.suit.localizedName)")
            } else {
                message.summaryText = templateLayout.caption
            }
            
            switch gameType {
            case .ginRummy:
                templateLayout.image = UIImage(named: "GinDefault")
                templateLayout.caption = NSLocalizedString("Your turn in Gin!", comment: "iMessage layout caption")
            case .crazy8s:
                templateLayout.image = UIImage(named: "CardGamesDefault")
                templateLayout.caption = "Your turn in Crazy 8s!"
            case .golf:
                templateLayout.image = UIImage(named: "CardGamesDefault")
                templateLayout.caption = "Your turn in Golf!"
                message.summaryText = "Your turn in Golf!" //figure out what the summary text for golf should be
            case .spades:
                templateLayout.image = UIImage(named: "CardGamesDefault")
                templateLayout.caption = "Your turn in Spades!"
                message.summaryText = "Your turn in Spades!" //figure out what the summary text for golf should be
            }
        }
        
        let liveLayout = MSMessageLiveLayout(alternateLayout: templateLayout)
        message.layout = liveLayout
        
        activeGameEngine?.clearMidTurnState(conversationID: conversation.localParticipantIdentifier.uuidString)
        
        // ...aaaand send!
        conversation.send(message) { error in
            if let error = error { print(error) }
        }
    }
    
    private func extractGameInfo(from message: MSMessage) -> (type: GameType, data: Data)? {
        guard let url = message.url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        
        // Extract the state data first (both old and new apps will always have this)
        guard let stateString = components.queryItems?.first(where: { $0.name == "gameState" })?.value,
              let stateData = Data(base64Encoded: stateString) else { return nil }
        
        // Look for the game type. If it's missing or invalid, default to Gin Rummy for legacy support.
        let typeString = components.queryItems?.first(where: { $0.name == "gameType" })?.value
        let gameType = GameType(rawValue: typeString ?? "") ?? .ginRummy
        
        return (type: gameType, data: stateData)
    }
    
    private func loadGameStateToMemory(from message: MSMessage, conversation: MSConversation, isExplicitChange: Bool = false) {
        guard let gameInfo = extractGameInfo(from: message) else { return }
        
        switch gameInfo.type {
        case .ginRummy:
            self.activeGameEngine = GinRummyManager.shared
        case .crazy8s:
            self.activeGameEngine = Crazy8sManager.shared
        case .golf:
            print("attempted to create golf game engine")
            // self.activeGameEngine = GolfManager.shared
            break
        case .spades:
            print("attempted to create spades game engine")
            // self.activeGameEngine = SpadesManager.shared
            break
        }
        
        setupEngineListener()
        
        let senderID = message.senderParticipantIdentifier
        let isFromMe = !conversation.remoteParticipantIdentifiers.contains(senderID)
        activeGameEngine?.loadState(
            from: gameInfo.data,
            isPlayersTurn: !isFromMe,
            conversationID: conversation.localParticipantIdentifier.uuidString,
            isExplicitChange: isExplicitChange)
    }
    
    private func setupEngineListener() {
        self.activeGameEngine?.onTurnCompleted = { [weak self] stateData, gameType in
            self?.sendGameMove(gameType: gameType, stateData: stateData)
        }
    }
}


enum GameType: String, Codable {
    case ginRummy
    case crazy8s
    case golf
    case spades
}

protocol GameEngine: AnyObject {
    var onTurnCompleted: ((Data, GameType) -> Void)? { get set }
    var playerHand: [Card] { get } // Used to check if a game is loaded
    var playerHasWon: Bool { get } // Used for setting iMessage captions
    var discardPile: [Card] { get } // Used for setting iMessage summary text
    
    func createNewGameState(withHandSize: Int) -> Data?
    func loadState(from data: Data, isPlayersTurn: Bool, conversationID: String, isExplicitChange: Bool)
    func saveMidTurnState(conversationID: String)
    func clearMidTurnState(conversationID: String)
}
