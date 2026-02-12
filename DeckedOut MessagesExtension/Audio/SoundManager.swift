//
//  SoundManager.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 12/19/25.
//

import Foundation
import UIKit //only for haptics
import AVFoundation

class SoundManager: NSObject, AVAudioPlayerDelegate { //ALSO HANDLES HAPTICS (seperate later?)
    static let instance = SoundManager()
    
    // Background Music Playlist Config
    private let songNames = ["bestElevator", "genericElevator", "jazzyElevator"]
    private var currentSongIndex: Int = -1
    
    // Audio Players
    private var backgroundMusicPlayer: AVAudioPlayer?
    private var cardDealPlayer: AVAudioPlayer?
    private var cardSlapPlayer: AVAudioPlayer?
    private var gameOverPlayer: AVAudioPlayer?
    
    // Haptics
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let hapticNotifications = UINotificationFeedbackGenerator()

    
    //MARK: - INIT
    private override init() {
        super.init()
        setupSFX()
        setupHaptics()
        NotificationCenter.default.addObserver(self,
            selector: #selector(handleSecondaryAudioChange),
            name: AVAudioSession.silenceSecondaryAudioHintNotification,
            object: nil)
    }
    
    private func setupSFX() {
        if let dealUrl = Bundle.main.url(forResource: "CardDeal", withExtension: "wav") {
            cardDealPlayer = try? AVAudioPlayer(contentsOf: dealUrl)
            cardDealPlayer?.volume = 0.3
            cardDealPlayer?.prepareToPlay()
        }
        if let slapUrl = Bundle.main.url(forResource: "CardSlap", withExtension: "wav") {
            cardSlapPlayer = try? AVAudioPlayer(contentsOf: slapUrl)
            cardSlapPlayer?.volume = 0.15
            cardSlapPlayer?.prepareToPlay()
        }
    }
    
    private func setupHaptics() {
        selectionFeedback.prepare()
        mediumImpact.prepare()
        hapticNotifications.prepare()
    }
    
    
    //MARK: - Public Play Triggers
    func playCardDeal() {
        cardDealPlayer?.currentTime = 0 //is the redundant? doesnt it default to the start?
        cardDealPlayer?.play()
        //softImpact.impactOccurred()
    }
    
    func playCardSlap() {
        cardSlapPlayer?.currentTime = 0
        cardSlapPlayer?.play()
        mediumImpact.impactOccurred()
    }
    
    func playCardReorder() {
        selectionFeedback.selectionChanged()
    }
    
    func playErrorFeedback() {
        hapticNotifications.notificationOccurred(.error)
    }
    
    func playGameEnd(didWin: Bool) {
        let fileToPlay = didWin ? "GameWin" : "GameLoss"
        if let gameOverUrl = Bundle.main.url(forResource: fileToPlay, withExtension: "mp3") {
            gameOverPlayer = try? AVAudioPlayer(contentsOf: gameOverUrl)
            gameOverPlayer?.volume = 0.3
            gameOverPlayer?.play()
        }
    }
    
    func startBackgroundMusic() {
        if backgroundMusicPlayer?.isPlaying == true { return }
        playRandomSong() // Nothing playing? Start a song!
    }
    
    func stopBackgroundMusic() {
        backgroundMusicPlayer?.stop()
    }
    
    
    //MARK: - Background Music Helper Functions
    private func playRandomSong() {
        // If the user is already playing audio, skip playing game background music
        if AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint { return }
        var newIndex = Int.random(in: 0..<songNames.count) // Pick a random song that isn't the one currently playing
        while newIndex == currentSongIndex && songNames.count > 1 {
            newIndex = Int.random(in: 0..<songNames.count)
        }
        
        currentSongIndex = newIndex
        let songName = songNames[newIndex]
        
        playSong(named: songName)
    }
    
    private func playSong(named songName: String) {
        guard let url = Bundle.main.url(forResource: songName, withExtension: "mp3") else { return }
        
        do {
            backgroundMusicPlayer = try AVAudioPlayer(contentsOf: url)
            backgroundMusicPlayer?.delegate = self // IMPORTANT: Tells us when the song ends
            backgroundMusicPlayer?.volume = 0.15
            backgroundMusicPlayer?.prepareToPlay()
            backgroundMusicPlayer?.play()
        } catch {
            print("SoundManager: Error loading \(songName): \(error)")
        }
    }
    
    @objc func handleSecondaryAudioChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionSilenceSecondaryAudioHintTypeKey] as? UInt,
              let type = AVAudioSession.SilenceSecondaryAudioHintType(rawValue: typeValue) else { return }

        if type == .begin {
            // User started playing music elsewhere -> Fade out ours
            backgroundMusicPlayer?.setVolume(0, fadeDuration: 1.0)
        } else {
            // User stopped their music -> Fade ours back in
            backgroundMusicPlayer?.play()
            backgroundMusicPlayer?.setVolume(0.15, fadeDuration: 1.0)
        }
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if player == backgroundMusicPlayer {
            // Song finished? Start the next one!
            playRandomSong()
        }
    }
}
