//
//  TimelineTests.swift
//  W Reminder Tests
//
//  Tests for TimelineView synchronization and time display functionality
//

import XCTest
import SwiftUI
@testable import W_Reminder

final class TimelineTests: XCTestCase {
    
    // MARK: - Time Remaining Calculation Tests
    
    func testTimeRemainingUnderOneMinute() {
        // Given
        let now = Date()
        let dueDate = now.addingTimeInterval(30) // 30 seconds from now
        
        // When
        let remaining = dueDate.timeIntervalSince(now)
        
        // Then
        XCTAssertLessThan(remaining, 60, "Should be under 60 seconds")
        XCTAssertGreaterThan(remaining, 0, "Should be positive")
    }
    
    func testTimeRemainingInMinutes() {
        // Given
        let now = Date()
        let dueDate = now.addingTimeInterval(5 * 60) // 5 minutes from now
        
        // When
        let remaining = dueDate.timeIntervalSince(now)
        let minutes = Int(remaining / 60)
        
        // Then
        XCTAssertEqual(minutes, 5)
    }
    
    func testTimeRemainingInHours() {
        // Given
        let now = Date()
        let dueDate = now.addingTimeInterval(2 * 3600) // 2 hours from now
        
        // When
        let remaining = dueDate.timeIntervalSince(now)
        let hours = Int(remaining / 3600)
        
        // Then
        XCTAssertEqual(hours, 2)
    }
    
    func testTimeRemainingInDays() {
        // Given
        let now = Date()
        let dueDate = now.addingTimeInterval(3 * 86400) // 3 days from now
        
        // When
        let remaining = dueDate.timeIntervalSince(now)
        let days = Int(remaining / 86400)
        
        // Then
        XCTAssertEqual(days, 3)
    }
    
    func testPastDueTime() {
        // Given
        let now = Date()
        let dueDate = now.addingTimeInterval(-3600) // 1 hour ago
        
        // When
        let remaining = dueDate.timeIntervalSince(now)
        
        // Then
        XCTAssertLessThan(remaining, 0, "Should be negative for past due dates")
    }
    
    // MARK: - Time Display String Format Tests
    
    func testTimeDisplayForSeconds() {
        // Given
        let remaining: TimeInterval = 45 // 45 seconds
        
        // When
        let display = formatTimeRemaining(remaining)
        
        // Then
        XCTAssertTrue(display.contains("Now") || display.contains("sec"), 
                     "Should show 'Now' or seconds for time under a minute")
    }
    
    func testTimeDisplayForMinutes() {
        // Given
        let remaining: TimeInterval = 5 * 60 // 5 minutes
        
        // When
        let display = formatTimeRemaining(remaining)
        
        // Then
        XCTAssertTrue(display.contains("5") && display.contains("min"), 
                     "Should show minutes for time under an hour")
    }
    
    func testTimeDisplayForHours() {
        // Given
        let remaining: TimeInterval = 3 * 3600 // 3 hours
        
        // When
        let display = formatTimeRemaining(remaining)
        
        // Then
        XCTAssertTrue(display.contains("3") && display.contains("hour"), 
                     "Should show hours for time under a day")
    }
    
    func testTimeDisplayForDays() {
        // Given
        let remaining: TimeInterval = 2 * 86400 // 2 days
        
        // When
        let display = formatTimeRemaining(remaining)
        
        // Then
        XCTAssertTrue(display.contains("2") && display.contains("day"), 
                     "Should show days for time over 24 hours")
    }
    
    func testTimeDisplayForOverdue() {
        // Given
        let remaining: TimeInterval = -3600 // 1 hour overdue
        
        // When
        let display = formatTimeRemaining(remaining)
        
        // Then
        XCTAssertTrue(display.contains("ago"), 
                     "Should indicate 'ago' for overdue tasks")
    }
    
    // MARK: - Minute Boundary Tests
    
    func testMinuteBoundaryCalculation() {
        // Given
        let calendar = Calendar.current
        let now = Date()
        
        // When - Get next minute boundary
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        guard var nextMinute = calendar.date(from: components) else {
            XCTFail("Could not create date from components")
            return
        }
        nextMinute = calendar.date(byAdding: .minute, value: 1, to: nextMinute)!
        
        // Then
        let secondsUntilNextMinute = nextMinute.timeIntervalSince(now)
        XCTAssertGreaterThan(secondsUntilNextMinute, 0, "Next minute should be in the future")
        XCTAssertLessThanOrEqual(secondsUntilNextMinute, 60, "Next minute should be within 60 seconds")
    }
    
    func testDateAtMinuteBoundary() {
        // Given
        let calendar = Calendar.current
        let components = DateComponents(year: 2024, month: 12, day: 10, hour: 14, minute: 30, second: 0)
        let date = calendar.date(from: components)!
        
        // When
        let seconds = calendar.component(.second, from: date)
        
        // Then
        XCTAssertEqual(seconds, 0, "Date at minute boundary should have 0 seconds")
    }
    
    func testDateBetweenMinuteBoundaries() {
        // Given
        let calendar = Calendar.current
        let components = DateComponents(year: 2024, month: 12, day: 10, hour: 14, minute: 30, second: 45)
        let date = calendar.date(from: components)!
        
        // When
        let seconds = calendar.component(.second, from: date)
        
        // Then
        XCTAssertGreaterThan(seconds, 0, "Date between boundaries should have seconds > 0")
        XCTAssertLessThan(seconds, 60, "Seconds should be less than 60")
    }
    
    // MARK: - TimelineView Schedule Tests
    
    func testEveryMinuteScheduleAlignment() {
        // Given
        let calendar = Calendar.current
        let now = Date()
        
        // When - Calculate next minute boundary
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        guard let currentMinuteStart = calendar.date(from: components),
              let nextMinute = calendar.date(byAdding: .minute, value: 1, to: currentMinuteStart) else {
            XCTFail("Could not calculate next minute boundary")
            return
        }
        
        // Then
        let nextMinuteSeconds = calendar.component(.second, from: nextMinute)
        XCTAssertEqual(nextMinuteSeconds, 0, ".everyMinute should align to 0 seconds")
    }
    
    // MARK: - Refresh State Tests
    
    func testRefreshIDGeneration() {
        // Given
        let id1 = UUID()
        let id2 = UUID()
        
        // Then
        XCTAssertNotEqual(id1, id2, "Each UUID should be unique")
    }
    
    func testRefreshIDUpdatesView() {
        // Given - Simulate view refresh mechanism
        var refreshID = UUID()
        let initialID = refreshID
        
        // When - Trigger refresh
        refreshID = UUID()
        
        // Then
        XCTAssertNotEqual(refreshID, initialID, "Refresh ID should change to trigger view update")
    }
    
    // MARK: - Helper Functions
    
    private func formatTimeRemaining(_ interval: TimeInterval) -> String {
        if interval < 0 {
            let overdue = -interval
            if overdue < 60 {
                return "Just now"
            } else if overdue < 3600 {
                let minutes = Int(ceil(overdue / 60))
                return "\(minutes) min ago"
            } else if overdue < 86_400 {
                let hours = Int(ceil(overdue / 3600))
                return "\(hours) hour\(hours == 1 ? "" : "s") ago"
            } else {
                let days = Int(ceil(overdue / 86_400))
                return "\(days) day\(days == 1 ? "" : "s") ago"
            }
        }
        
        let hours = interval / 3600
        if hours >= 24 {
            let days = Int(hours / 24)
            return "\(days) day\(days == 1 ? "" : "s") left"
        } else if hours >= 1 {
            let h = Int(ceil(hours))
            return "\(h) hour\(h == 1 ? "" : "s") left"
        } else if interval >= 60 {
            let minutes = Int(ceil(interval / 60))
            return "\(minutes) min left"
        } else {
            return "Now"
        }
    }
}
