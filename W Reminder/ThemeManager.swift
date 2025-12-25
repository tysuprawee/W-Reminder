//
//  ThemeManager.swift
//  W Reminder
//
//  Created for Gamification
//

import SwiftUI
import Combine

@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var showUnlockCelebration = false
    @Published var newlyUnlockedTheme: Theme?
    
    private let unlockedKey = "unlockedThemeIds"
    
    private init() {}
    
    func checkUnlocks() {
        let previouslyUnlocked = UserDefaults.standard.stringArray(forKey: unlockedKey) ?? []
        var newUnlocked: [String] = previouslyUnlocked
        var foundNew = false
        
        for theme in Theme.all {
            // Skip if already known
            if previouslyUnlocked.contains(theme.id) { continue }
            
            // Check if unlocked now
            if isUnlocked(theme) {
                // New unlock!
                if !foundNew {
                    // Only show one at a time for simplicity
                    self.newlyUnlockedTheme = theme
                    self.showUnlockCelebration = true
                    foundNew = true
                }
                newUnlocked.append(theme.id)
            }
        }
        
        if newUnlocked.count != previouslyUnlocked.count {
            UserDefaults.standard.set(newUnlocked, forKey: unlockedKey)
        }
    }
    
    private func isUnlocked(_ theme: Theme) -> Bool {
        guard let req = theme.unlockRequirement else { return true }
        
        switch req {
        case .level(let level):
            return LevelManager.shared.currentLevel >= level
        case .invites(let needed):
            return (AuthManager.shared.profile?.invitationsCount ?? 0) >= needed
        case .streak(let needed):
            return StreakManager.shared.currentStreak >= needed
        case .premium:
            return false // TODO
        }
    }
}
