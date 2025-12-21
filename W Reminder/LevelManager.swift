//
//  LevelManager.swift
//  W Reminder
//
//  Created for Gamification
//

import Foundation
import SwiftData
import SwiftUI
import Combine

/// Manages Experience (EXP), Levels, and Achievements
@Observable
final class LevelManager {
    static let shared = LevelManager()
    
    // MARK: - Properties
    
    // Current Stats
    var currentExp: Int = 0
    var currentLevel: Int = 1
    
    // Achievements
    var unlockedAchievementIds: [String] = []
    
    // Event Publishers for UI Animations
    @ObservationIgnored let xpGainedSubject = PassthroughSubject<Int, Never>()
    @ObservationIgnored let achievementUnlockedSubject = PassthroughSubject<Achievement, Never>()
    
    // Config
    private let expPerTask = 10
    private let expPerStreak = 25
    private let expPerLevelBase = 50 // New easier curve (was 100)
    
    // Persistence Keys
    private let keyExp = "userExp"
    private let keyLevel = "userLevel"
    private let keyAchievements = "userAchievements" 
    
    private init() {
        loadData()
    }
    
    // MARK: - Logic
    
    // Simple Formula: Threshold = Level * 50
    // Level 1 -> 50 XP to reach Level 2
    // Level 2 -> 100 XP (Total 150) to reach Level 3? 
    // Wait, let's stick to "XP Accumulated".
    // Level = (TotalEXP / 50) + 1
    
    var expForNextLevel: Int {
        return currentLevel * expPerLevelBase
    }
    
    var expProgress: Double {
        // Calculate progress within current level
        // Previous Level Cap = (Level-1) * 50
        let levelBase = (currentLevel - 1) * expPerLevelBase
        let currentLevelExp = currentExp - levelBase
        
        let requiredForNext = expPerLevelBase // Linear progression for simplicity (every level needs 50 new XP)
        // If we want scaling: required = Level * 50.
        // Let's stick to Linear (Every 50xp = 1 Level) to keep it fast/easy as requested.
        
        return Double(currentLevelExp) / Double(requiredForNext)
    }
    
    func addExp(_ amount: Int) {
        currentExp += amount
        xpGainedSubject.send(amount) // Trigger Animation
        checkLevelUp()
        saveData()
    }
    
    func checkLevelUp() {
        // Linear Formula: Level = (TotalEXP / 50) + 1
        let calculatedLevel = (currentExp / expPerLevelBase) + 1
        
        if calculatedLevel > currentLevel {
            // Level Up!
            currentLevel = calculatedLevel
            // Trigger Animation via StreakManager (or we can add a new one)
            StreakManager.shared.showCelebration = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                StreakManager.shared.showCelebration = false
            }
        }
    }
    
    // MARK: - Achievements
    
    func checkAchievements(totalTasks: Int, streak: Int) {
        // Example Achievements
        if totalTasks >= 1 { unlock(id: "first_task") }
        if totalTasks >= 10 { unlock(id: "10_tasks") }
        if totalTasks >= 50 { unlock(id: "50_tasks") }
        
        if streak >= 3 { unlock(id: "streak_3") }
        if streak >= 7 { unlock(id: "streak_7") }
        if streak >= 30 { unlock(id: "streak_30") }
    }
    
    private func unlock(id: String) {
        if !unlockedAchievementIds.contains(id) {
            unlockedAchievementIds.append(id)
            saveData()
            
            if let achievement = getAchievement(id: id) {
                achievementUnlockedSubject.send(achievement) // Trigger Banner
                print("Achievement Unlocked: \(id)")
            }
        }
    }
    
    func getAchievement(id: String) -> Achievement? {
        return Achievement.all.first { $0.id == id }
    }
    
    // MARK: - Persistence
    
    func loadData() {
        let defaults = UserDefaults.standard
        currentExp = defaults.integer(forKey: keyExp)
        currentLevel = (currentExp / 100) + 1 // Recalculate level from EXP to be safe
        
        if let str = defaults.string(forKey: keyAchievements) {
            unlockedAchievementIds = str.components(separatedBy: ",")
        }
    }
    
    func saveData() {
        let defaults = UserDefaults.standard
        defaults.set(currentExp, forKey: keyExp)
        defaults.set(currentLevel, forKey: keyLevel)
        defaults.set(unlockedAchievementIds.joined(separator: ","), forKey: keyAchievements)
        
        // Sync to cloud?
        Task {
            await AuthManager.shared.updateGamification(
                exp: currentExp, 
                level: currentLevel, 
                achievements: unlockedAchievementIds.joined(separator: ",")
            )
        }
    }
    
    // MARK: - Cloud Sync
    
    /// Merges Cloud data with Local data robustly (Safety Checks)
    func importFromCloud(exp: Int, level: Int, achievementsString: String) {
        // 1. Gamification Strategy: Always take the highest value to prevent data loss
        // (e.g., if local has 500xp but cloud has 400xp, keep 500xp)
        if exp > self.currentExp {
            self.currentExp = exp
        }
        
        if level > self.currentLevel {
            self.currentLevel = level
        }
        
        // 2. Achievements Strategy: Union of sets
        let cloudIds = achievementsString.components(separatedBy: ",")
        let localSet = Set(self.unlockedAchievementIds)
        let cloudSet = Set(cloudIds)
        
        let mergedSet = localSet.union(cloudSet)
        // Filter empty strings if any
        self.unlockedAchievementIds = Array(mergedSet).filter { !$0.isEmpty }
        
        saveData() // Persist merged state
    }
    
    /// Clears all local gamification data (Used on Sign Out)
    func resetLocalData() {
        currentExp = 0
        currentLevel = 1
        unlockedAchievementIds = []
        
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: keyExp)
        defaults.removeObject(forKey: keyLevel)
        defaults.removeObject(forKey: keyAchievements)
        defaults.synchronize()
    }
}

// MARK: - Models

struct Achievement: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    
    static let all: [Achievement] = [
        Achievement(id: "first_task", title: "Getting Started", description: "Complete your first task", icon: "checkmark.circle.fill"),
        Achievement(id: "10_tasks", title: "Productive", description: "Complete 10 tasks", icon: "list.bullet.circle.fill"),
        Achievement(id: "50_tasks", title: "Machine", description: "Complete 50 tasks", icon: "trophy.fill"),
        Achievement(id: "streak_3", title: "Consistency", description: "Reach a 3-day streak", icon: "flame.fill"),
        Achievement(id: "streak_7", title: "On Fire", description: "Reach a 7-day streak", icon: "flame.circle.fill"),
        Achievement(id: "streak_30", title: "Unstoppable", description: "Reach a 30-day streak", icon: "crown.fill"),
    ]
}
