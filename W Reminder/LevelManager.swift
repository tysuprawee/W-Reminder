//
//  LevelManager.swift
//  W Reminder
//
//  Created for Gamification
//

import Foundation
import SwiftData
import SwiftUI

/// Manages Experience (EXP), Levels, and Achievements
@Observable
final class LevelManager {
    static let shared = LevelManager()
    
    // MARK: - Properties
    
    // Current Stats
    var currentExp: Int = 0
    var currentLevel: Int = 1
    
    // Achievements
    // In a real app, this might be a separate Model, but for simplicity we can store unlocked IDs
    var unlockedAchievementIds: [String] = []
    
    // Config
    private let expPerTask = 10
    private let expPerStreak = 25
    
    // Persistence Keys
    private let keyExp = "userExp"
    private let keyLevel = "userLevel"
    private let keyAchievements = "userAchievements" // Comma separated string
    
    private init() {
        loadData()
    }
    
    // MARK: - Logic
    
    // Calculated based on a curve, e.g. Level = sqrt(EXP) * constant
    // Or simple milestone list.
    // Let's use: Level N requires 100 * N EXP total? Or simpler: 
    // Level 1: 0-100
    // Level 2: 101-250
    // etc.
    
    // Simple Formula: Threshold = Level * 100
    // Current Level Progress
    var expForNextLevel: Int {
        return currentLevel * 100
    }
    
    var expProgress: Double {
        // This is simplified. Proper RPG logic usually tracks "current level exp" separately.
        // Let's assume currentExp accumulates forever (Total EXP).
        // We need to calculate how much EXP was needed for *previous* levels to know "current bar".
        // Let's keep it very simple: Reset EXP on Level Up? No, Total EXP is better for leaderboard.
        
        // Total EXP needed for Level L = 50 * L * (L-1) ... Argh.
        // Let's just use:
        // Level = floor(0.1 * sqrt(EXP)) + 1
        // EXP = ((Level-1)/0.1)^2
        // Let's stick to linear-ish for now: 100xp per level increment.
        // Level 1: 0-99
        // Level 2: 100-199
        // Level 3: 200...
        
        let levelBase = (currentLevel - 1) * 100
        let currentLevelExp = currentExp - levelBase
        return Double(currentLevelExp) / 100.0
    }
    
    func addExp(_ amount: Int) {
        currentExp += amount
        checkLevelUp()
        saveData()
    }
    
    func checkLevelUp() {
        // Formula: Level = (EXP / 100) + 1
        let calculatedLevel = (currentExp / 100) + 1
        
        if calculatedLevel > currentLevel {
            // Level Up!
            currentLevel = calculatedLevel
            // Trigger Animation or Celebration via StreakManager
            StreakManager.shared.showCelebration = true
            
            // Re-hide celebration after delay? StreakManager handles that.
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
            // Could show a specific "Achievement Unlocked" toast
            print("Achievement Unlocked: \(id)")
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
