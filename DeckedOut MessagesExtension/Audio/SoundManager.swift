//
//  SoundManager.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 12/19/25.
//

import Foundation
import UIKit //only for haptics
import AVFoundation

class SoundManager { //ALSO HANDLES HAPTICS (seperate later?)
    static let instance = SoundManager()
    private var cardDealPlayer: AVAudioPlayer?
    private var cardSlapPlayer: AVAudioPlayer?
    private var gameOverPlayer: AVAudioPlayer?
    
    // Haptics
    private let selectionFeedback = UISelectionFeedbackGenerator()
    //private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let hapticNotificatoins = UINotificationFeedbackGenerator()

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
        selectionFeedback.prepare()
        //softImpact.prepare()
        mediumImpact.prepare()
        hapticNotificatoins.prepare()
    }

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
        hapticNotificatoins.notificationOccurred(.error)
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
