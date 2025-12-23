//
//  HapticManager.swift
//  W Reminder
//
//  Created for Enhanced Game Feel
//

import SwiftUI
import UIKit

final class HapticManager {
    static let shared = HapticManager()
    
    // User Preference Storage (Reuse the key if it exists, or define it here)
    @AppStorage("isHapticsEnabled") private var isEnabled: Bool = true
    
    private init() {}
    
    enum HapticStyle {
        case success      // Completing a task, Level Up
        case error        // Action failed
        case warning      // Destructive action (Delete)
        case selection    // Toggle, Tab change
        case light        // Subtle interaction
        case medium       // Standard interaction
        case heavy        // Impactful interaction
        case rigid        // Sharp, mechanical feel (Perfect for checkboxes)
        case soft         // Gentle bump
    }
    
    func play(_ style: HapticStyle) {
        guard isEnabled else { return }
        
        switch style {
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .heavy:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .rigid:
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        case .soft:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
    }
    
    // Specialized Trigger for "Game Feel" events
    func triggerConfetti() {
        guard isEnabled else { return }
        // A complex pattern for big wins
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Follow up with smaller taps? (Requires async delay, usually overkill for V1, stick to success)
    }
}
