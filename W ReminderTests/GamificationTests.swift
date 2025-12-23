//
//  GamificationTests.swift
//  W ReminderTests
//
//  Created for Gamification Logic Verification
//

import XCTest
@testable import W_Reminder

@MainActor
final class GamificationTests: XCTestCase {
    
    // Use the same defaults suite as StreakManager logic
    private var testDefaults: UserDefaults {
        if let suite = UserDefaults(suiteName: SharedPersistence.appGroupIdentifier) {
            return suite
        }
        return .standard
    }
    
    override func setUp() {
        super.setUp()
        LevelManager.shared.resetLocalData()
        StreakManager.shared.resetLocalData()
        // Ensure manual wipe of testDefaults too if resetLocalData() missed it
        testDefaults.removePersistentDomain(forName: SharedPersistence.appGroupIdentifier)
    }
    
    override func tearDown() {
        LevelManager.shared.resetLocalData()
        StreakManager.shared.resetLocalData()
        testDefaults.removePersistentDomain(forName: SharedPersistence.appGroupIdentifier)
        super.tearDown()
    }
    
    // MARK: - Level Manager Tests
    
    func testLevelOneInitialization() {
        let manager = LevelManager.shared
        XCTAssertEqual(manager.currentLevel, 1)
        XCTAssertEqual(manager.currentExp, 0)
    }
    
    func testLevelUpCalculation() {
        let manager = LevelManager.shared
        
        // Formula: Level = sqrt(EXP / 50) + 1
        // Need 50 XP to hit Level 2
        manager.addExp(50)
        
        XCTAssertEqual(manager.currentExp, 50)
        XCTAssertEqual(manager.currentLevel, 2, "50 XP should reach Level 2")
        
        // Need 200 XP to hit Level 3
        manager.addExp(150)
        XCTAssertEqual(manager.currentExp, 200)
        XCTAssertEqual(manager.currentLevel, 3, "200 XP should reach Level 3")
    }
    
    func testExpProgressCalculation() {
        let manager = LevelManager.shared
        
        // Level 1: 0 to 50.
        // Add 25 XP
        manager.addExp(25)
        
        // Progress should be 25/50 = 0.5
        XCTAssertEqual(manager.expProgress, 0.5, accuracy: 0.01)
    }
    
    func testUnlockAchievement() {
        let manager = LevelManager.shared
        
        // Verify locked initially
        XCTAssertFalse(manager.unlockedAchievementIds.contains("first_task"))
        
        // Unlock condition: 1 task
        manager.checkAchievements(totalTasks: 1, streak: 0)
        
        XCTAssertTrue(manager.unlockedAchievementIds.contains("first_task"))
    }
    
    // MARK: - Streak Manager Tests
    
    func testStreakInitialization() {
        let manager = StreakManager.shared
        XCTAssertEqual(manager.currentStreak, 0)
        XCTAssertFalse(manager.isStreakActiveToday)
    }
    
    func testFirstCompletionIncrementsStreak() {
        let manager = StreakManager.shared
        
        manager.incrementStreak()
        
        XCTAssertEqual(manager.currentStreak, 1)
        XCTAssertTrue(manager.isStreakActiveToday)
    }
    
    func testStreakActiveForDay() {
        let manager = StreakManager.shared
        manager.incrementStreak()
        
        // Simulate completing another task SAME DAY
        manager.incrementStreak()
        
        // Streak should NOT increment again today
        XCTAssertEqual(manager.currentStreak, 1)
        XCTAssertTrue(manager.isStreakActiveToday)
    }
    
    func testStreakContinuation() {
        // Logic: Manipulate UserDefaults
        let defaults = testDefaults
        
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        
        defaults.set(5, forKey: "userStreakCount")
        defaults.set(yesterday, forKey: "userLastCompletionDate")
        
        // Force Manager to reload
        StreakManager.shared.checkStreak()
        
        // Verify state "Yesterday was done, pending today"
        XCTAssertEqual(StreakManager.shared.currentStreak, 5)
        XCTAssertFalse(StreakManager.shared.isStreakActiveToday, "Should not be active for today yet")
        
        // Action: Complete Task
        StreakManager.shared.incrementStreak()
        
        // Verify Increment
        XCTAssertEqual(StreakManager.shared.currentStreak, 6)
        XCTAssertTrue(StreakManager.shared.isStreakActiveToday)
    }
    
    func testStreakBreak() {
        let defaults = testDefaults
        let calendar = Calendar.current
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: Date())!
        
        defaults.set(10, forKey: "userStreakCount")
        defaults.set(twoDaysAgo, forKey: "userLastCompletionDate")
        
        StreakManager.shared.checkStreak()
        
        XCTAssertEqual(StreakManager.shared.currentStreak, 0)
        
        StreakManager.shared.incrementStreak()
        
        XCTAssertEqual(StreakManager.shared.currentStreak, 1)
    }
}
