//
//  StreakManager.swift
//  W Reminder
//

import Foundation
import SwiftUI
import WidgetKit

/// Manages user streaks for habit building.
@Observable
final class StreakManager {
    static let shared = StreakManager()
    
    // Public Observable Properties
    var currentStreak: Int = 0
    var isStreakActiveToday: Bool = false // True if a task was completed today
    
    // Persistence Keys
    private let keyStreak = "userStreakCount"
    private let keyLastDate = "userLastCompletionDate"
    
    // Shared Defaults
    private var defaults: UserDefaults? {
        UserDefaults(suiteName: SharedPersistence.appGroupIdentifier)
    }
    
    private init() {
        loadStreak()
    }
    
    /// Call this whenever a task is completed
    func incrementStreak() {
        let now = Date()
        let calendar = Calendar.current
        let userDefaults = defaults ?? .standard
        
        // 1. Check if already completed something today
        if let lastDate = userDefaults.object(forKey: keyLastDate) as? Date {
            if calendar.isDateInToday(lastDate) {
                // Already extended today
                isStreakActiveToday = true
                
                // Ensure widget updates even if logic says "already done" (e.g. re-completing)
                WidgetCenter.shared.reloadAllTimelines()
                return
            }
            
            // 2. Check if streak is broken (last date was before yesterday)
            if !calendar.isDateInYesterday(lastDate) {
                // Streak broken! Reset to 1 (since we just did one)
                currentStreak = 1
            } else {
                // Extended!
                currentStreak += 1
            }
        } else {
            // First ever completion
            currentStreak = 1
        }
        
        // Save
        isStreakActiveToday = true
        userDefaults.set(currentStreak, forKey: keyStreak)
        userDefaults.set(now, forKey: keyLastDate)
        
        // Reload Widgets
        WidgetCenter.shared.reloadAllTimelines()
        
        // Push to Cloud
        Task {
            await AuthManager.shared.updateStreak(count: self.currentStreak, lastActive: now)
        }
    }
    
    /// Call this on app launch to verify if streak is stale
    func checkStreak() {
        loadStreak()
    }
    
    private func loadStreak() {
        let userDefaults = defaults ?? .standard
        let storedStreak = userDefaults.integer(forKey: keyStreak)
        let lastDate = userDefaults.object(forKey: keyLastDate) as? Date
        
        let calendar = Calendar.current
        
        if let lastDate {
            if calendar.isDateInToday(lastDate) {
                // Active today
                currentStreak = storedStreak
                isStreakActiveToday = true
            } else if calendar.isDateInYesterday(lastDate) {
                // Valid streak, pending today
                currentStreak = storedStreak
                isStreakActiveToday = false
            } else {
                // Broken streak
                isStreakActiveToday = false
                currentStreak = 0 
            }
        } else {
            currentStreak = 0
            isStreakActiveToday = false
        }
    }
    // MARK: - Cloud Sync Helpers
    
    /// Updates local streak from Cloud data (Force Override)
    func updateFromCloud(count: Int, lastDate: Date?) {
        let userDefaults = defaults ?? .standard
        
        self.currentStreak = count
        // Calculate active state based on cloud date
        if let lastDate {
            let calendar = Calendar.current
            if calendar.isDateInToday(lastDate) {
                self.isStreakActiveToday = true
            } else if calendar.isDateInYesterday(lastDate) {
                self.isStreakActiveToday = false
            } else {
                self.isStreakActiveToday = false
                // Note: If cloud thinks streak is X but date is old, maybe we shouldn't trust count?
                // But let's trust cloud for now.
            }
            userDefaults.set(lastDate, forKey: keyLastDate)
        } else {
            self.isStreakActiveToday = false
            userDefaults.removeObject(forKey: keyLastDate)
        }
        
        userDefaults.set(count, forKey: keyStreak)
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    var lastCompletionDate: Date? {
        let userDefaults = defaults ?? .standard
        return userDefaults.object(forKey: keyLastDate) as? Date
    }
}
