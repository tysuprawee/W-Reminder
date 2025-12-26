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
@MainActor
final class LevelManager {
    static let shared = LevelManager()
    
    // MARK: - Properties
    
    // Current Stats
    var currentExp: Int = 0
    var currentLevel: Int = 1
    var totalTasksCompleted: Int = 0
    
    // Achievements
    var unlockedAchievementIds: [String] = []
    
    // UI State
    var showLevelUpCelebration: Bool = false
    
    // Event Publishers for UI Animations
    @ObservationIgnored let xpGainedSubject = PassthroughSubject<Int, Never>()
    @ObservationIgnored let achievementUnlockedSubject = PassthroughSubject<Achievement, Never>()
    
    // Config
    private let expPerTask = 10
    private let expPerStreak = 25
    private let expPerLevelBase = 35 // New easier curve (was 100, then 50)
    
    // Persistence Keys
    private let keyExp = "userExp"
    private let keyLevel = "userLevel"
    private let keyAchievements = "userAchievements" 
    private let keyTotalTasks = "userTotalTasks"
    
    private init() {
        loadData()
    }
    
    // MARK: - Logic
    
    // Quadratic Formula: TotalXP = 35 * (Level - 1)^2
    // Level = sqrt(TotalXP / 35) + 1
    //
    // Lvl 1: 0 XP
    // Lvl 2: 35 XP (Gap 35)
    // Lvl 3: 140 XP (Gap 105)
    // Harder as you go!
    
    var expForNextLevel: Int {
        return 35 * (currentLevel * currentLevel)
    }
    
    var expForCurrentLevel: Int {
        return 35 * ((currentLevel - 1) * (currentLevel - 1))
    }
    
    var expProgress: Double {
        let currentBase = expForCurrentLevel
        let nextBase = expForNextLevel
        let required = nextBase - currentBase
        let gained = currentExp - currentBase
        
        guard required > 0 else { return 0 }
        return Double(gained) / Double(required)
    }
    
    func addExp(_ amount: Int) {
        currentExp += amount
        xpGainedSubject.send(amount) // Trigger Animation
        checkLevelUp()
        saveData()
    }
    
    func checkLevelUp() {
        // Recalculate based on total EXP
        let calculatedLevel = Int(sqrt(Double(currentExp) / Double(expPerLevelBase))) + 1
        
        if calculatedLevel > currentLevel {
            // Level Up!
            currentLevel = calculatedLevel
            // Trigger Animation
            showLevelUpCelebration = true
            
            // Wait for Level Up celebration to finish before showing Theme Unlock
            // This prevents UI conflict/overlap
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                self.showLevelUpCelebration = false
                ThemeManager.shared.checkUnlocks() 
            }
            
            // Check Level-based achievements
            checkLevelAchievements()
        }
    }
    
    // MARK: - Achievements
    
    func incrementTaskCount(by amount: Int = 1) {
        totalTasksCompleted += amount
        saveData()
        checkAchievements()
    }
    
    func checkAchievements() {
        let totalTasks = totalTasksCompleted
        let streak = StreakManager.shared.currentStreak
        // Task Count Achievements (Very Frequent Rewards)
        if totalTasks >= 1 { unlock(id: "first_task") }
        if totalTasks >= 10 { unlock(id: "10_tasks") }
        if totalTasks >= 25 { unlock(id: "25_tasks") }
        if totalTasks >= 50 { unlock(id: "50_tasks") }
        if totalTasks >= 75 { unlock(id: "75_tasks") }
        if totalTasks >= 100 { unlock(id: "100_tasks") }
        if totalTasks >= 150 { unlock(id: "150_tasks") }
        if totalTasks >= 200 { unlock(id: "200_tasks") }
        if totalTasks >= 300 { unlock(id: "300_tasks") }
        if totalTasks >= 400 { unlock(id: "400_tasks") }
        if totalTasks >= 500 { unlock(id: "500_tasks") }
        if totalTasks >= 750 { unlock(id: "750_tasks") }
        if totalTasks >= 1000 { unlock(id: "1000_tasks") }
        
        // Streak Achievements (Weeks & Months)
        if streak >= 3 { unlock(id: "streak_3") }
        if streak >= 7 { unlock(id: "streak_7") }
        if streak >= 14 { unlock(id: "streak_14") }
        if streak >= 21 { unlock(id: "streak_21") }
        if streak >= 30 { unlock(id: "streak_30") }
        if streak >= 40 { unlock(id: "streak_40") }
        if streak >= 50 { unlock(id: "streak_50") }
        if streak >= 60 { unlock(id: "streak_60") }
        if streak >= 75 { unlock(id: "streak_75") }
        if streak >= 90 { unlock(id: "streak_90") }
        if streak >= 100 { unlock(id: "streak_100") }
        
        checkLevelAchievements()
        checkTimeSensitiveAchievements()
        
        // Trigger generic unlock check (covers possible future task-based themes)
        DispatchQueue.main.async {
            ThemeManager.shared.checkUnlocks()
        }
    }
    
    private func checkTimeSensitiveAchievements() {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let weekday = calendar.component(.weekday, from: now) // 1=Sun, 7=Sat
        
        // Early Bird: Before 8 AM (0-7)
        if hour < 8 {
            unlock(id: "early_bird")
        }
        
        // Weekend Warrior: Saturday (7) or Sunday (1)
        if weekday == 1 || weekday == 7 {
            unlock(id: "weekend_warrior")
        }
    }
    
    private func checkLevelAchievements() {
        if currentLevel >= 2 { unlock(id: "level_2") }
        if currentLevel >= 5 { unlock(id: "level_5") }
        if currentLevel >= 8 { unlock(id: "level_8") }
        if currentLevel >= 10 { unlock(id: "level_10") }
        if currentLevel >= 15 { unlock(id: "level_15") }
        if currentLevel >= 20 { unlock(id: "level_20") }
        if currentLevel >= 25 { unlock(id: "level_25") }
        if currentLevel >= 30 { unlock(id: "level_30") }
        if currentLevel >= 35 { unlock(id: "level_35") }
        if currentLevel >= 40 { unlock(id: "level_40") }
        if currentLevel >= 45 { unlock(id: "level_45") }
        if currentLevel >= 50 { unlock(id: "level_50") }
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
        currentLevel = Int(sqrt(Double(currentExp) / Double(expPerLevelBase))) + 1 // Recalculate using quadratic
        totalTasksCompleted = defaults.integer(forKey: keyTotalTasks)
        
        if let str = defaults.string(forKey: keyAchievements) {
            unlockedAchievementIds = str.components(separatedBy: ",")
        }
    }
    
    func saveData() {
        let defaults = UserDefaults.standard
        defaults.set(currentExp, forKey: keyExp)
        defaults.set(currentLevel, forKey: keyLevel)
        defaults.set(totalTasksCompleted, forKey: keyTotalTasks)
        defaults.set(unlockedAchievementIds.joined(separator: ","), forKey: keyAchievements)
        
        // Sync to cloud?
        Task {
            await AuthManager.shared.updateGamification(
                exp: currentExp, 
                level: currentLevel, 
                achievements: unlockedAchievementIds.joined(separator: ","),
                totalTasks: totalTasksCompleted
            )
        }
    }
    
    // MARK: - Cloud Sync
    
    /// Merges Cloud data with Local data robustly (Safety Checks)
    func importFromCloud(exp: Int, level: Int, achievementsString: String, totalTasks: Int = 0) {
        // 1. Gamification Strategy: Always take the highest value to prevent data loss
        // (e.g., if local has 500xp but cloud has 400xp, keep 500xp)
        if exp > self.currentExp {
            self.currentExp = exp
        }
        
        if totalTasks > self.totalTasksCompleted {
            self.totalTasksCompleted = totalTasks
        }
        
        // Recalculate Level locally based on max XP to ensure consistency with new Curve
        self.currentLevel = Int(sqrt(Double(self.currentExp) / Double(expPerLevelBase))) + 1
        
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
        print("LevelManager: Resetting local data...")
        currentExp = 0
        currentLevel = 1
        totalTasksCompleted = 0
        unlockedAchievementIds = []
        
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: keyExp)
        defaults.removeObject(forKey: keyLevel)
        defaults.removeObject(forKey: keyTotalTasks)
        defaults.removeObject(forKey: keyAchievements)
        let success = defaults.synchronize()
        print("LevelManager: Reset complete. Success: \(success)")
    }
}

// MARK: - Models

struct Achievement: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    
    static let all: [Achievement] = [
        // MARK: TASKS - Early Game (1-100)
        Achievement(id: "first_task", title: "First Step", description: "Complete your first task", icon: "shoeprints.fill"),
        Achievement(id: "10_tasks", title: "Warming Up", description: "Complete 10 tasks", icon: "figure.walk"),
        Achievement(id: "25_tasks", title: "Gaining Momentum", description: "Complete 25 tasks", icon: "figure.run"),
        Achievement(id: "50_tasks", title: "Half Century", description: "Complete 50 tasks", icon: "flag.fill"),
        Achievement(id: "75_tasks", title: "On a Roll", description: "Complete 75 tasks", icon: "bicycle"),
        Achievement(id: "100_tasks", title: "Centurion", description: "Complete 100 tasks", icon: "rosette"),
        
        // MARK: TASKS - Mid Game (150-1000)
        Achievement(id: "150_tasks", title: "Taskmaster", description: "Complete 150 tasks", icon: "list.clipboard.fill"),
        Achievement(id: "200_tasks", title: "Double Century", description: "Complete 200 tasks", icon: "doc.on.doc.fill"),
        Achievement(id: "300_tasks", title: "Spartan", description: "Complete 300 tasks", icon: "shield.checkered"),
        Achievement(id: "400_tasks", title: "Four Score", description: "Complete 400 tasks", icon: "square.grid.4x3.fill"),
        Achievement(id: "500_tasks", title: "The Machine", description: "Complete 500 tasks", icon: "gearshape.2.fill"),
        Achievement(id: "750_tasks", title: "Juggernaut", description: "Complete 750 tasks", icon: "bolt.horizontal.fill"),
        Achievement(id: "1000_tasks", title: "Legendary", description: "Complete 1,000 tasks", icon: "crown.fill"),
        
        // MARK: STREAKS (Days)
        Achievement(id: "streak_3", title: "Hat Trick", description: "Reach a 3-day streak", icon: "flame.fill"),
        Achievement(id: "streak_7", title: "One Week", description: "Reach a 7-day streak", icon: "7.circle.fill"),
        Achievement(id: "streak_14", title: "Fortnight", description: "Reach a 14-day streak", icon: "calendar"),
        Achievement(id: "streak_21", title: "Habit Former", description: "Reach a 21-day streak", icon: "brain.head.profile"),
        Achievement(id: "streak_30", title: "Monthly Master", description: "Reach a 30-day streak", icon: "calendar.badge.checkmark"),
        Achievement(id: "streak_40", title: "Disciplined", description: "Reach a 40-day streak", icon: "stopwatch.fill"),
        Achievement(id: "streak_50", title: "Golden 50", description: "Reach a 50-day streak", icon: "star.circle.fill"),
        Achievement(id: "streak_60", title: "Two Months", description: "Reach a 60-day streak", icon: "calendar.circle.fill"),
        Achievement(id: "streak_75", title: "Diamond", description: "Reach a 75-day streak", icon: "suit.diamond.fill"),
        Achievement(id: "streak_90", title: "Quarterly", description: "Reach a 90-day streak", icon: "chart.pie.fill"),
        Achievement(id: "streak_100", title: "Century Streak", description: "Reach a 100-day streak", icon: "crown.fill"),

        // MARK: LEVELS
        Achievement(id: "level_2", title: "Novice", description: "Reach Level 2", icon: "leaf"),
        Achievement(id: "level_5", title: "Apprentice", description: "Reach Level 5", icon: "book.fill"),
        Achievement(id: "level_8", title: "Scholar", description: "Reach Level 8", icon: "eyeglasses"),
        Achievement(id: "level_10", title: "Journeyman", description: "Reach Level 10", icon: "hammer.fill"),
        Achievement(id: "level_15", title: "Adept", description: "Reach Level 15", icon: "pencil.and.ruler.fill"),
        Achievement(id: "level_20", title: "Expert", description: "Reach Level 20", icon: "star.square.fill"),
        Achievement(id: "level_25", title: "Professional", description: "Reach Level 25", icon: "briefcase.fill"),
        Achievement(id: "level_30", title: "Master", description: "Reach Level 30", icon: "graduationcap.fill"),
        Achievement(id: "level_35", title: "Elite", description: "Reach Level 35", icon: "medal.fill"),
        Achievement(id: "level_40", title: "Grandmaster", description: "Reach Level 40", icon: "trophy.fill"),
        Achievement(id: "level_45", title: "Hero", description: "Reach Level 45", icon: "shield.fill"),
        Achievement(id: "level_50", title: "Immortal", description: "Reach Level 50", icon: "infinity"),
        
        // MARK: TIME & SPECIAL
        Achievement(id: "early_bird", title: "Early Bird", description: "Complete a task before 8 AM", icon: "sunrise.fill"),
        Achievement(id: "weekend_warrior", title: "Weekend Warrior", description: "Complete a task on the weekend", icon: "tent.fill"),
    ]
}
