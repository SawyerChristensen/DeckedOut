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
    
    //private let lightImpact = UIImpactFeedbackGenerator(style: .light) //haptics
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)

    private init() {
        if let dealUrl = Bundle.main.url(forResource: "CardDeal", withExtension: "wav") {
            cardDealPlayer = try? AVAudioPlayer(contentsOf: dealUrl)
            cardDealPlayer?.volume = 0.2
            cardDealPlayer?.prepareToPlay()
        }
        if let slapUrl = Bundle.main.url(forResource: "CardSlap", withExtension: "wav") {
            cardSlapPlayer = try? AVAudioPlayer(contentsOf: slapUrl)
            cardSlapPlayer?.volume = 0.1
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
}
