//
//  SoundManager.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 12/19/25.
//

import Foundation
import AVFoundation

nonisolated class SoundManager: NSObject, AVAudioPlayerDelegate { //ALSO HANDLES HAPTICS (seperate later?)
    static let instance = SoundManager()
    
    // Background Music Playlist Config
    private let songNames = ["bestElevator", "genericElevator", "jazzyElevator"]
    private var currentSongIndex: Int = -1
    
    // Audio Players
    private var backgroundMusicPlayer: AVAudioPlayer?
    /// Whether the game currently wants music, as opposed to whether the player happens to be
    /// running. An audio session interruption — a phone call, Siri, an alarm — pauses
    /// `backgroundMusicPlayer` behind our back and never resumes it on its own, so the two can
    /// drift apart; `handleInterruption` uses this to know whether to put them back together.
    private var musicShouldBePlaying = false
    /// Which view controller the music belongs to. iMessage runs several `MSMessagesAppViewController`
    /// instances inside one extension process — the app itself, plus one per live-layout bubble in
    /// the transcript — and every one of them reaches this same shared singleton. Every move sends a
    /// message, every message adds a bubble, and the transcript instances behind it are created and
    /// torn down as that happens; their `willResignActive` must not be able to stop the music
    /// playing in the game sitting on top of them.
    private weak var musicOwner: AnyObject?
    private var cardDealPlayer: AVAudioPlayer?
    private var cardSlapPlayer: AVAudioPlayer?
    private var gameOverPlayer: AVAudioPlayer?

    //MARK: - INIT
    private override init() {
        super.init()
        setupSFX()
        NotificationCenter.default.addObserver(self,
            selector: #selector(handleSecondaryAudioChange),
            name: AVAudioSession.silenceSecondaryAudioHintNotification,
            object: nil)
        NotificationCenter.default.addObserver(self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil)
        NotificationCenter.default.addObserver(self,
            selector: #selector(handleMediaServicesReset),
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: nil)
    }
    
    private func setupSFX() {
        if let dealUrl = Bundle.main.url(forResource: "CardDeal", withExtension: "aac") {
            cardDealPlayer = try? AVAudioPlayer(contentsOf: dealUrl)
            cardDealPlayer?.volume = 0.3
            cardDealPlayer?.prepareToPlay()
        }
        if let slapUrl = Bundle.main.url(forResource: "CardSlap", withExtension: "aac") {
            cardSlapPlayer = try? AVAudioPlayer(contentsOf: slapUrl)
            cardSlapPlayer?.volume = 0.15
            cardSlapPlayer?.prepareToPlay()
        }
    }
    
    
    //MARK: - Public Play Triggers
    func playCardDeal() {
        cardDealPlayer?.currentTime = 0
        cardDealPlayer?.play()
    }
    
    func playCardSlap() {
        cardSlapPlayer?.currentTime = 0
        cardSlapPlayer?.play()
    }
    
    func playGameEnd(didWin: Bool) {
        let fileToPlay = didWin ? "GameWin" : "GameLoss"
        if let gameOverUrl = Bundle.main.url(forResource: fileToPlay, withExtension: "mp3") {
            gameOverPlayer = try? AVAudioPlayer(contentsOf: gameOverUrl)
            gameOverPlayer?.volume = 0.3
            gameOverPlayer?.play()
        }
    }
    
    func startBackgroundMusic(owner: AnyObject) {
        musicOwner = owner
        musicShouldBePlaying = true
        if backgroundMusicPlayer?.isPlaying == true { return }
        if backgroundMusicPlayer != nil { // Paused by an interruption -> pick the song back up where it left off
            resumeBackgroundMusic()
            return
        }
        playRandomSong() // Nothing playing? Start a song!
    }

    /// Only whoever started the music can stop it — see `musicOwner`. A `nil` owner means the
    /// instance that started it is gone, so there is no one left to stop it on behalf of.
    func stopBackgroundMusic(owner: AnyObject) {
        guard musicOwner == nil || musicOwner === owner else { return }
        musicOwner = nil
        musicShouldBePlaying = false
        backgroundMusicPlayer?.stop()
        backgroundMusicPlayer = nil // Drop the player so the next game opens on a freshly picked song
    }

    /// Put the music back on if something silenced it without our asking — see `musicShouldBePlaying`.
    private func resumeBackgroundMusicIfNeeded() {
        guard musicShouldBePlaying, let player = backgroundMusicPlayer, !player.isPlaying else { return }
        resumeBackgroundMusic()
    }

    private func resumeBackgroundMusic() {
        // The user put their own audio on while we were quiet -> stay out of the way.
        if AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint { return }
        try? AVAudioSession.sharedInstance().setActive(true) // An interruption leaves the session deactivated
        backgroundMusicPlayer?.play()
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

        onMain {
            if type == .begin {
                // User started playing music elsewhere -> Fade out ours
                self.backgroundMusicPlayer?.setVolume(0, fadeDuration: 1.0)
            } else {
                // User stopped their music -> Fade ours back in
                self.backgroundMusicPlayer?.play()
                self.backgroundMusicPlayer?.setVolume(0.15, fadeDuration: 1.0)
            }
        }
    }

    /// `AVAudioPlayer` pauses itself when the session is interrupted — a phone call, Siri, an
    /// alarm — and stays paused forever unless someone starts it again. A game is sat in for
    /// minutes at a time, so that is worth coming back from.
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            break // The player has already paused itself; `musicShouldBePlaying` remembers we want it back
        case .ended:
            // Deliberately not gated on the `.shouldResume` option: this is ambient background
            // music at 0.15 volume for a game the user is still sitting in front of, and
            // `resumeBackgroundMusic()` already defers to any audio of their own.
            onMain { self.resumeBackgroundMusicIfNeeded() }
        @unknown default:
            break
        }
    }

    /// A media services reset invalidates every `AVAudioPlayer` we hold, so rebuild the lot.
    @objc private func handleMediaServicesReset(notification: Notification) {
        onMain {
            let wantsMusic = self.musicShouldBePlaying

            self.cardDealPlayer = nil
            self.cardSlapPlayer = nil
            self.gameOverPlayer = nil
            self.backgroundMusicPlayer = nil

            try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try? AVAudioSession.sharedInstance().setActive(true)

            self.setupSFX()
            if wantsMusic, let owner = self.musicOwner { self.startBackgroundMusic(owner: owner) }
        }
    }

    /// Audio session notifications arrive on whatever thread the session server posts them from,
    /// and `AVAudioPlayer` isn't thread-safe — every player here is created and driven on main.
    private func onMain(_ work: @escaping @Sendable () -> Void) {
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if player == backgroundMusicPlayer {
            // Song finished? Start the next one!
            playRandomSong()
        }
    }
}
