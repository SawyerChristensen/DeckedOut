//
//  SoundManager.swift
//  DeckedOut
//
//  Created by Sawyer Christensen on 12/19/25.
//

import UIKit

class HapticManager {
    static let instance = HapticManager()
    
    // Haptics
    private var selectionFeedback = UISelectionFeedbackGenerator()
    private var mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private var hapticNotifications = UINotificationFeedbackGenerator()
    
    // INIT
    private init() {
        selectionFeedback.prepare()
        mediumImpact.prepare()
        hapticNotifications.prepare()
    }
    
    // Public Play Triggers
    func playCardSlap() {
        mediumImpact.impactOccurred()
    }
    
    func playCardReorder() {
        selectionFeedback.selectionChanged()
    }
    
    func playErrorFeedback() {
        hapticNotifications.notificationOccurred(.error)
    }
}
