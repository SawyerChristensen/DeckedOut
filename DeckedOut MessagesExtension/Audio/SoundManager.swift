//
//  SoundManager.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 12/19/25.
//

import Foundation
import UIKit //only for haptics
import AVFoundation

class SoundManager {
    static let instance = SoundManager()
    private var cardDealPlayer: AVAudioPlayer?
    private var cardSlapPlayer: AVAudioPlayer?
    private var gameOverPlayer: AVAudioPlayer?
    
    //private let lightImpact = UIImpactFeedbackGenerator(style: .light) //haptics
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)

    private init() {
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
        //lightImpact.prepare()
        mediumImpact.prepare()
    }

    func playCardDeal() {
        cardDealPlayer?.currentTime = 0
        cardDealPlayer?.play()
    }
    
    func playCardSlap() {
        cardSlapPlayer?.currentTime = 0
        cardSlapPlayer?.play()
        mediumImpact.impactOccurred()
    }
    
    func playGameWin(didWin: Bool) {
        let fileToPlay = didWin ? "GameWin" : "GameLoss"
        if let gameOverUrl = Bundle.main.url(forResource: fileToPlay, withExtension: "mp3") {
            gameOverPlayer = try? AVAudioPlayer(contentsOf: gameOverUrl)
            gameOverPlayer?.volume = 0.3
            gameOverPlayer?.play()
        }
    }
}
