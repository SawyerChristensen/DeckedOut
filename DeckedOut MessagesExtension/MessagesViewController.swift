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
        setupFeedbackSystems()
        updateAccessibilityModal(for: presentationStyle)
        NotificationCenter.default.addObserver(self, selector: #selector(sceneWillDeactivate(_:)), name: UIScene.willDeactivateNotification, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Fallback for first launch via App Store "Open" — willBecomeActive(with:) may not fire before the view is shown, leaving the screen blank. Only present if nothing is already loaded and we're not in a transcript instance or about to open into a game.
        if presentationStyle != .transcript
            && children.isEmpty
            && activeGameEngine == nil
            && activeConversation?.selectedMessage == nil {
            presentMenuView(for: presentationStyle)
        }
    }

    @objc private func sceneWillDeactivate(_ notification: Notification) { //for detecting scene closues on ipad
        guard let scene = notification.object as? UIScene,
              scene == view.window?.windowScene else { return }
        SoundManager.instance.stopBackgroundMusic()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let currentWidth = self.view.bounds.width
        if let engine = activeGameEngine, engine.extensionWidth != currentWidth {
            engine.extensionWidth = currentWidth
        }
    }
    
    private func setupFeedbackSystems() {
        _ = HapticManager.instance //init Haptic engine on main thread (required)
        
        do { //setup audio session
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default) //.ambient allows mixing with background music and respects silent switch
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            //print("Could not set up audio session: \(error)")
        }
        
        Task.detached(priority: .userInitiated) { //init audio off the main launch path
            _ = await SoundManager.instance
        }

        /*Task.detached(priority: .utility) { //authenticate Game Center on background thread
            GameCenterManager.shared.authenticate()
            GameCenterManager.shared.syncAchievementsWithWinCounts()
        }*/
    }

    
    // MARK: - Conversation Handling
    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        guard let message = conversation.selectedMessage, // Do we have a message? Can we decode it?
            let gameInfo = extractGameInfo(from: message) else { //No message to decode, the user is opening the main menu
            if presentationStyle != .transcript && children.isEmpty {
                presentMenuView(for: presentationStyle)
            }
            return
        }

        let isFromMe = !conversation.remoteParticipantIdentifiers.contains(message.senderParticipantIdentifier)

        if presentationStyle == .transcript {
            presentTranscriptView(for: gameInfo.type, stateData: gameInfo.data, isFromMe: isFromMe, localParticipantID: conversation.localParticipantIdentifier)
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
        guard presentationStyle != .transcript else { return } // Transcript instances must never load game state or wire the send callback
        loadGameStateToMemory(from: message, conversation: conversation)
    }

    override func didReceive(_ message: MSMessage, conversation: MSConversation) {
        super.didReceive(message, conversation: conversation)
        guard presentationStyle != .transcript else { return } // Transcript instances must never load game state or wire the send callback
        loadGameStateToMemory(from: message, conversation: conversation)
    }

    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.willTransition(to: presentationStyle)
        updateAccessibilityModal(for: presentationStyle)

        let isGameLoaded = activeGameEngine != nil
        let isShowingMenu = children.first is UIHostingController<MainMenuView>

        if !isGameLoaded && isShowingMenu { // Menu resizing
            withAnimation(.easeInOut(duration: 0.3)) {
                menuViewModel?.presentationStyle = presentationStyle }
            return
        }

        if presentationStyle == .expanded {
            if isGameLoaded { // A game IS loaded but game isn't on screen yet -> Show it.
                if let conversation = activeConversation, let selectedMessage = conversation.selectedMessage { // Make sure it's the game the user tapped
                    loadGameStateToMemory(from: selectedMessage, conversation: conversation, isExplicitChange: true)
                }
                presentGameView()
            } else {  // Expanded, but no game loaded -> Show Menu
                presentMenuView(for: presentationStyle)
            }
        } else { // view is compact -> Always Menu
            presentMenuView(for: presentationStyle)
        }
    }
    
    // MARK: - View Presentation
    private func presentTranscriptView(for gameType: GameType, stateData: Data, isFromMe: Bool, localParticipantID: UUID) {
        let rootView = decideTranscriptView(for: gameType, stateData: stateData, isFromMe: isFromMe, localParticipantID: localParticipantID)
        let transcriptViewController = UIHostingController(rootView: rootView)
        presentView(transcriptViewController)
    }

    @ViewBuilder
    private func decideTranscriptView(for gameType: GameType?, stateData: Data, isFromMe: Bool, localParticipantID: UUID) -> some View {
        switch gameType {
            
        case .ginRummy, .none: //.none is for users recieving a game from pre-2.0 users
            // Try V2 (groupchat multiplayer) first, then fall back to V1
            if let v2State = try? JSONDecoder().decode(GinRummyV2GameState.self, from: stateData) {
                if v2State.seats.contains(GinRummyManager.unclaimedSeat) {
                    GinTranscriptInvite( // Game invite view
                        gameState: v2State,
                        onHeightChange: { [weak self] height in
                            self?.transcriptHeight = height
                        }
                    )
                    .onTapGesture {
                        self.requestPresentationStyle(.expanded)
                    }
                } else { // The user has joined! Display groupchat transcript view
                    GinTranscriptV2(
                        gameState: v2State,
                        localParticipantID: localParticipantID,
                        onHeightChange: { [weak self] height in
                            self?.transcriptHeight = height
                        }
                    )
                    .onTapGesture {
                        self.requestPresentationStyle(.expanded)
                    }
                }
            // Legacy pre-3.0 Game State
            } else if let decodedState = try? JSONDecoder().decode(GinRummyGameState.self, from: stateData) {
                if decodedState.turnNumber == 0 { // Game invite
                    GinTranscriptInvite(
                        inviterCardBackOverride: decodedState.senderCardBack,
                        onHeightChange: { [weak self] height in
                            self?.transcriptHeight = height
                        }
                    )
                    .onTapGesture {
                        self.requestPresentationStyle(.expanded)
                    }
                } else { // 1v1 mid-game transcript view
                    GinTranscriptLegacy(
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
            // Try V2 (groupchat multiplayer) first, then fall back to V1
            if let v2State = try? JSONDecoder().decode(Crazy8sV2GameState.self, from: stateData) {
                if v2State.seats.contains(Crazy8sManager.unclaimedSeat) {
                    Crazy8sTranscriptInvite( // Game invite view
                        gameState: v2State,
                        onHeightChange: { [weak self] height in
                            self?.transcriptHeight = height
                        }
                    )
                    .onTapGesture {
                        self.requestPresentationStyle(.expanded)
                    }
                } else { // The user has joined! Display groupchat transcript view
                    Crazy8sTranscriptV2(
                        gameState: v2State,
                        localParticipantID: localParticipantID,
                        onHeightChange: { [weak self] height in
                            self?.transcriptHeight = height
                        }
                    )
                    .onTapGesture {
                        self.requestPresentationStyle(.expanded)
                    }
                }
            // Legacy pre-3.0 Game State
            } else if let legacyState = try? JSONDecoder().decode(Crazy8sLegacyGameState.self, from: stateData) {
                if legacyState.turnNumber == 0 { // Game invite view
                    Crazy8sTranscriptInvite(
                        inviterCardBackOverride: legacyState.senderCardBack,
                        onHeightChange: { [weak self] height in
                            self?.transcriptHeight = height
                        }
                    )
                    .onTapGesture {
                        self.requestPresentationStyle(.expanded)
                    }
                } else { // 1v1 mid-game transcript view
                    Crazy8sTranscriptLegacy(
                        gameState: legacyState,
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
                Text("Error loading match data.")  // Fallback UI in case the data is corrupted or decoding fails (should never trigger)
                    .padding()
            }
   
            
        case .golf:
            // Try V2 (groupchat multiplayer) first, then fall back to V1
            if let v2State = try? JSONDecoder().decode(GolfV2GameState.self, from: stateData) {
                if v2State.seats.contains(GolfManager.unclaimedSeat) {
                    GolfTranscriptInvite( // Game invite view
                        gameState: v2State,
                        onHeightChange: { [weak self] height in
                            self?.transcriptHeight = height
                        }
                    )
                    .onTapGesture {
                        self.requestPresentationStyle(.expanded)
                    }
                } else { // The user has joined! Display groupchat transcript view
                    GolfTranscriptV2(
                        gameState: v2State,
                        localParticipantID: localParticipantID,
                        onHeightChange: { [weak self] height in
                            self?.transcriptHeight = height
                        }
                    )
                    .onTapGesture {
                        self.requestPresentationStyle(.expanded)
                    }
                }
            // Legacy pre-3.0 Game State
            } else if let decodedState = try? JSONDecoder().decode(GolfGameState.self, from: stateData) {
                if decodedState.turnNumber == 0 { // Game invite
                    GolfTranscriptInvite(
                        inviterCardBackOverride: decodedState.senderCardBack,
                        onHeightChange: { [weak self] height in
                            self?.transcriptHeight = height
                        }
                    )
                    .onTapGesture {
                        self.requestPresentationStyle(.expanded)
                    }
                } else { // 1v1 mid-game transcript view
                    GolfTranscriptLegacy(
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
                Text("Error loading match data.")  // Fallback UI in case the data is corrupted or decoding fails (should never trigger)
                    .padding()
            }
        case .unknown:
            Text("New game! \nUpdate your app to play!")
                .font(.system(.headline, design: .serif, weight: .semibold))
                .multilineTextAlignment(.center)
                .padding()
                .frame(maxWidth: .infinity)
                .background(FeltBackgroundView())
        }
    }
    
    private func presentMenuView(for presentationStyle: MSMessagesAppPresentationStyle) {
        let viewModel = MenuViewModel(presentationStyle: presentationStyle)
        self.menuViewModel = viewModel

        let menuView = MainMenuView(viewModel: viewModel) { [weak self] gameType, selectedSize in
            guard let self = self, let conversation = self.activeConversation else { return }
            self.createGame(conversation: conversation, gameType: gameType, handSize: selectedSize)
        }

        presentView(UIHostingController(rootView: menuView))
        SoundManager.instance.stopBackgroundMusic()
    }
    
    private func presentGameView() {
        guard let engine = activeGameEngine else { return }
        let gameViewController: UIViewController
        
        engine.extensionWidth = self.view.bounds.width
        
        if let ginManager = engine as? GinRummyManager {
            if self.children.first is UIHostingController<GinRootView> { return }
            gameViewController = UIHostingController(rootView: GinRootView(game: ginManager))
            
        } else if let crazy8sManager = engine as? Crazy8sManager {
            if self.children.first is UIHostingController<Crazy8sRootView> { return }
            gameViewController = UIHostingController(rootView: Crazy8sRootView(game: crazy8sManager))
            
        } else if let golfManager = engine as? GolfManager {
            if self.children.first is UIHostingController<GolfRootView> { return }
            gameViewController = UIHostingController(rootView: GolfRootView(game: golfManager))
            
        } else {
            return
        }
        
        presentView(gameViewController)
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
    
    private func updateAccessibilityModal(for presentationStyle: MSMessagesAppPresentationStyle) {
        view.accessibilityViewIsModal = (presentationStyle == .expanded) //in order to block the imessage elements underneath the view from being recognized/assigned numbers
    }
    
    // MARK: - Game Sending
    private func createGame(conversation: MSConversation, gameType: GameType, handSize: Int = 7) {
        let session = MSSession()
        let message = MSMessage(session: session)
        let templateLayout = MSMessageTemplateLayout()
        
        //define template loadout view for non-iOS or iPadOS devices (macOS, visionOS, etc)
        templateLayout.image = UIImage(named: "CardGamesDefault")
        
        switch gameType {
        case .ginRummy:
            GinRummyManager.shared.handSize = handSize
            self.activeGameEngine = GinRummyManager.shared
            templateLayout.image = UIImage(named: "GinDefault")
            templateLayout.caption = NSLocalizedString("Let's Play Gin!", comment: "Gin invite caption/summary") //need to use NSLocalizedString here because it is not in a SwiftUI view and therefore automatically included in the localizable catalog. this adds it manually
        case .crazy8s:
            self.activeGameEngine = Crazy8sManager.shared
            templateLayout.image = UIImage(named: "Crazy8sDefault")
            templateLayout.caption = NSLocalizedString("Let's Play Crazy 8s!", comment: "Crazy 8s invite caption/summary")
        case .golf:
            self.activeGameEngine = GolfManager.shared
            templateLayout.image = UIImage(named: "GolfDefault")
            templateLayout.caption = NSLocalizedString("Let's Play Golf!", comment: "Golf invite caption/summary")
        case .unknown:
            fatalError("Cannot create a game with an unknown type")
        }
        
        message.layout = templateLayout
        message.summaryText = templateLayout.caption
        
        setupEngineListener()

        // Build a stable seat list from unique participants. In self-text chats,
        // there may be only one unique identifier, but we still want a 2-seat game.
        let seats = normalizedSeats(for: conversation)
        guard let stateData = activeGameEngine?.createNewGameState(seats: seats) else {
            print("Error: Could not generate starting game state for \(gameType)")
            return
        }
        let jsonString = stateData.base64EncodedString()
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "isSinglePlayer", value: String(activeGameEngine?.isSinglePlayer ?? true)),
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
        
        self.activeGameEngine = nil //set it back to nil to fix view transition bug. If we don't, willTransition thinks theres an active game when it hasn't been sent yet. activeGameEngine gets reactivated in didReceive/didSelect anyway
    }
    
    func sendGameMove(gameType: GameType, stateData: Data) {
        // Further package the game state
        let stateDataJSONString = stateData.base64EncodedString()
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "isSinglePlayer", value: String(activeGameEngine?.isSinglePlayer ?? true)),
            URLQueryItem(name: "gameType", value: gameType.rawValue),
            URLQueryItem(name: "gameState", value: stateDataJSONString)]
        
        // Create the message & attach data
        let conversation = activeConversation!
        //print("conversation:", conversation)
        let selectedMessage = conversation.selectedMessage!
        //print("selectedMessage:", selectedMessage)
        let session = selectedMessage.session!
        //print("session:", session)
        let message = MSMessage(session: session)
        //print("message:", message)
        message.url = components.url
        
        // Set basic template appearance
        let templateLayout = MSMessageTemplateLayout() //this will be overridden later with transcript view, this is just for non-live-layout platforms
        
        if activeGameEngine?.isGameOver == true {
            templateLayout.image = UIImage(named: "CardGameWon") //set as default here, override with game specific images later
            
            switch gameType {
            case .ginRummy:
                templateLayout.image = UIImage(named: "GinGameWon")
                if let ginManager = activeGameEngine as? GinRummyManager,
                   let roundWinType = ginManager.currentRoundWinType {
                    switch roundWinType {
                    case .gin:
                        templateLayout.caption = NSLocalizedString("I won in Gin!", comment: "Gin template win caption/summary")
                    case .knock:
                        templateLayout.caption = NSLocalizedString("I won by knock in Gin!", comment: "Gin template win caption/summary for knocking")
                    case .undercut:
                        templateLayout.caption = NSLocalizedString("You won by undercut in Gin!", comment: "Gin template win caption/summary for undercut")
                    }
                } else {
                    templateLayout.caption = NSLocalizedString("I won in Gin!", comment: "Gin template win caption/summary")
                }
            case .crazy8s:
                templateLayout.caption = NSLocalizedString("I won in Crazy 8s!", comment: "Crazy 8s template win caption/summary")
            case .golf:
                if activeGameEngine?.playerHasWon == true {
                    templateLayout.caption = NSLocalizedString("I won in Golf!", comment: "Golf template win caption/summary")
                } else {
                    templateLayout.caption = NSLocalizedString("You won in Golf!", comment: "Golf template win caption/summary")
                }
            case .unknown:
                templateLayout.caption = NSLocalizedString("I won!", comment: "Default template win caption/summary")
            }
            
            message.summaryText = templateLayout.caption //message summary always same as caption in win case
            
        } else { //its a normal non-winning game move
            templateLayout.image = UIImage(named: "CardGamesDefault")  //set as default here, override with game-specific images later
            
            switch gameType {
            case .ginRummy:
                templateLayout.image = UIImage(named: "GinDefault")
                templateLayout.caption = NSLocalizedString("Your turn in Gin!", comment: "Gin Rummy template message caption")
            case .crazy8s:
                templateLayout.image = UIImage(named: "Crazy8sDefault")
                templateLayout.caption =  NSLocalizedString("Your turn in Crazy 8s!", comment: "Crazy 8s template message caption")
            case .golf:
                templateLayout.image = UIImage(named: "GolfDefault")
                templateLayout.caption = NSLocalizedString("Your turn in Golf!", comment: "Golf template message caption")
            case .unknown:
                templateLayout.caption = NSLocalizedString("Your turn!", comment: "Default template message caption (never gets shown)")
            }
            
            if let discardedCard = activeGameEngine?.discardPile.last {
                message.summaryText = String(localized: "Discarded \(discardedCard.rank.localizedName) of \(discardedCard.suit.localizedName)")
            } else {
                message.summaryText = templateLayout.caption
            }
        }
        
        // Override templateLayout with transcript view
        let liveLayout = MSMessageLiveLayout(alternateLayout: templateLayout)
        message.layout = liveLayout
        
        // ...aaaand send!
        conversation.send(message) { error in
            if let error = error {
                print(error.localizedDescription)
            }
            else {
                //sent with no errors
                self.activeGameEngine?.clearMidTurnState(conversationID: conversation.localParticipantIdentifier.uuidString)
            }
        }

        // Assistive tech users don't generate a "recent touch interaction" with their move, so conversation.send only stages the message in the input field instead of sending it. Collapsing to compact surfaces the input field with the Send button so the user knows to send manually. Voice Control has no public detection API, so we check related assistive tech as a proxy.
        if UIAccessibility.isVoiceOverRunning
            || UIAccessibility.isSwitchControlRunning
            || UIAccessibility.isAssistiveTouchRunning
            || UIAccessibility.isSpeakScreenEnabled
            || UIAccessibility.isSpeakSelectionEnabled {
            requestPresentationStyle(.compact)
        }
    }
    
    private func sendJoinMessage(session: MSSession, conversation: MSConversation, gameType: GameType, isSinglePlayer: Bool, stateData: Data) {
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "isSinglePlayer", value: String(isSinglePlayer)),
            URLQueryItem(name: "gameType", value: gameType.rawValue),
            URLQueryItem(name: "gameState", value: stateData.base64EncodedString())]

        let message = MSMessage(session: session)
        message.url = components.url

        let templateLayout = MSMessageTemplateLayout()
        switch gameType {
        case .ginRummy:
            templateLayout.image = UIImage(named: "GinDefault")
            templateLayout.caption = NSLocalizedString("Joined Gin!", comment: "Gin join caption/summary")
        case .crazy8s:
            templateLayout.image = UIImage(named: "Crazy8sDefault")
            templateLayout.caption = NSLocalizedString("Joined Crazy 8s!", comment: "Crazy 8s join caption/summary")
        case .golf:
            templateLayout.image = UIImage(named: "GolfDefault")
            templateLayout.caption = NSLocalizedString("Joined Golf!", comment: "Golf join caption/summary")
        default:
            templateLayout.image = UIImage(named: "CardGamesDefault")
            templateLayout.caption = NSLocalizedString("Joined the game!", comment: "Default join caption/summary (Placeholder, should never show)")
        }
        message.summaryText = templateLayout.caption

        let liveLayout = MSMessageLiveLayout(alternateLayout: templateLayout)
        message.layout = liveLayout

        conversation.send(message)

        // Assistive tech users don't generate a "recent touch interaction" with their join, so conversation.send only stages the message in the input field instead of sending it. Collapsing to compact surfaces the input field with the Send button so the user knows to send manually. Voice Control has no public detection API, so we check related assistive tech as a proxy.
        if UIAccessibility.isVoiceOverRunning
            || UIAccessibility.isSwitchControlRunning
            || UIAccessibility.isAssistiveTouchRunning
            || UIAccessibility.isSpeakScreenEnabled
            || UIAccessibility.isSpeakSelectionEnabled {
            requestPresentationStyle(.compact)
        }
    }
    
    private func normalizedSeats(for conversation: MSConversation) -> [UUID] {
        var uniqueSeats: [UUID] = []
        for participantID in [conversation.localParticipantIdentifier] + conversation.remoteParticipantIdentifiers {
            if !uniqueSeats.contains(participantID) {
                uniqueSeats.append(participantID)
            }
        }

        // If the user is texting themselves, keep gameplay as a 2-seat match.
        if uniqueSeats.count == 1, let localID = uniqueSeats.first {
            return [localID, localID]
        }

        return uniqueSeats
    }

    // MARK: - Helper Functions
    private func extractGameInfo(from message: MSMessage) -> (type: GameType, data: Data, isSinglePlayer: Bool)? {
        guard let url = message.url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }

        // Extract the state data first (both old and new apps will always have this)
        guard let stateString = components.queryItems?.first(where: { $0.name == "gameState" })?.value,
              let stateData = Data(base64Encoded: stateString) else { return nil }

        // Look for the game type. If present, set it. If unrecognized (outdated client), default to unknown.
        // If missing, default to Gin Rummy (legacy support for users still on 1.x)
        let gameType: GameType
        if let typeString = components.queryItems?.first(where: { $0.name == "gameType" })?.value {
            gameType = GameType(rawValue: typeString) ?? .unknown
        } else {
            gameType = .ginRummy
        }

        // State format version: absent = 1 (legacy), 2 = seat-based multiplayer
        let versionString = components.queryItems?.first(where: { $0.name == "isSinglePlayer" })?.value
        let isSinglePlayer = Bool(versionString ?? "true") ?? true

        return (type: gameType, data: stateData, isSinglePlayer: isSinglePlayer)
    }
    
    private func loadGameStateToMemory(from message: MSMessage, conversation: MSConversation, isExplicitChange: Bool = false) {
        guard let gameInfo = extractGameInfo(from: message) else { return }

        switch gameInfo.type {
        case .ginRummy:
            self.activeGameEngine = GinRummyManager.shared
        case .crazy8s:
            self.activeGameEngine = Crazy8sManager.shared
        case .golf:
            self.activeGameEngine = GolfManager.shared
        case .unknown:
            print("Received unsupported or unknown game type")
            return
        }

        setupEngineListener()

        let senderID = message.senderParticipantIdentifier
        let isFromMe = !conversation.remoteParticipantIdentifiers.contains(senderID)
        activeGameEngine?.loadState(
            from: gameInfo.data,
            isPlayersTurn: !isFromMe,
            localParticipantID: conversation.localParticipantIdentifier,
            isSinglePlayer: gameInfo.isSinglePlayer,
            conversationID: conversation.localParticipantIdentifier.uuidString,
            isExplicitChange: isExplicitChange)
    }
    
    private func setupEngineListener() {
        self.activeGameEngine?.onTurnCompleted = { [weak self] stateData, gameType in
            self?.sendGameMove(gameType: gameType, stateData: stateData)
        }
        if let groupEngine = activeGameEngine as? any GroupChatCapable {
            groupEngine.onJoinCompleted = { [weak self] stateData, gameType in
                guard let self = self,
                      let conversation = self.activeConversation,
                      let selectedMessage = conversation.selectedMessage,
                      let session = selectedMessage.session else { return }
                self.sendJoinMessage(session: session, conversation: conversation, gameType: gameType, isSinglePlayer: groupEngine.isSinglePlayer, stateData: stateData)
            }
        }
    }
}


enum GameType: String, Codable {
    case ginRummy
    case crazy8s
    case golf
    case unknown
}

// MARK: - Game State Protocols
protocol BasicGameState: Codable {
    var sessionID: UUID { get }
    var deck: [Card] { get }
    var discardPile: [Card] { get }
    var turnNumber: Int { get }
}

protocol V2GameState: BasicGameState {
    var seats: [UUID] { get }
    var hands: [[Card]] { get }
    var currentSeatIndex: Int { get }
}

// MARK: - Game Engine Protocols
protocol GameEngine: AnyObject {
    var onTurnCompleted: ((Data, GameType) -> Void)? { get set }
    var playerHand: [Card] { get }  // Used to check if a game is loaded
    var isGameOver: Bool { get }    // Used for setting iMessage captions
    var playerHasWon: Bool { get }  // Used for setting iMessage captions
    var discardPile: [Card] { get } // Used for setting iMessage summary text
    var isSinglePlayer: Bool { get }
    var extensionWidth: CGFloat { get set }

    func createNewGameState(seats: [UUID]) -> Data?
    func loadState(from data: Data, isPlayersTurn: Bool, localParticipantID: UUID, isSinglePlayer: Bool, conversationID: String, isExplicitChange: Bool)
    func saveMidTurnState(conversationID: String)
    func clearMidTurnState(conversationID: String)
}

protocol GroupChatCapable: GameEngine {
    static var unclaimedSeat: UUID { get }
    var isJoiningPhase: Bool { get }
    var onJoinCompleted: ((Data, GameType) -> Void)? { get set }
    var joinWasOverwritten: Bool { get }
    
    func joinGame(shouldBroadcast: Bool)
}
