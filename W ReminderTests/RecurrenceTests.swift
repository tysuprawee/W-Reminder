//
//  RecurrenceTests.swift
//  W ReminderTests
//
//  Created for Recurrence Logic Verification
//

import XCTest
@testable import W_Reminder

final class RecurrenceTests: XCTestCase {
    
    // MARK: - Calculation Tests
    
    func testDailyRecurrence() {
        // Given
        let now = Date()
        let calendar = Calendar.current
        
        // When
        let nextDate = RecurrenceHelper.calculateNextDueDate(from: now, rule: "daily")
        
        // Then
        XCTAssertNotNil(nextDate)
        XCTAssertTrue(calendar.isDate(nextDate!, inSameDayAs: now.addingTimeInterval(86400))) // +1 Day
    }
    
    func testWeeklyRecurrence() {
        // Given
        let now = Date()
        let calendar = Calendar.current
        
        // When
        let nextDate = RecurrenceHelper.calculateNextDueDate(from: now, rule: "weekly")
        
        // Then
        XCTAssertNotNil(nextDate)
        // Check if roughly 7 days later
        let diff = calendar.dateComponents([.day], from: now, to: nextDate!)
        XCTAssertEqual(diff.day, 7)
    }
    
    func testMonthlyRecurrence() {
        // Given
        // Set a fixed date to avoid end-of-month edge cases for basic test (e.g., Jan 15)
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 15
        let calendar = Calendar.current
        let date = calendar.date(from: components)!
        
        // When
        let nextDate = RecurrenceHelper.calculateNextDueDate(from: date, rule: "monthly")
        
        // Then
        XCTAssertNotNil(nextDate)
        let nextComponents = calendar.dateComponents([.month, .day], from: nextDate!)
        XCTAssertEqual(nextComponents.month, 2)
        XCTAssertEqual(nextComponents.day, 15)
    }
    
    func testYearlyRecurrence() {
        // Given
        var components = DateComponents()
        components.year = 2024
        components.month = 5
        components.day = 10
        let calendar = Calendar.current
        let date = calendar.date(from: components)!
        
        // When
        let nextDate = RecurrenceHelper.calculateNextDueDate(from: date, rule: "yearly")
        
        // Then
        XCTAssertNotNil(nextDate)
        let nextComponents = calendar.dateComponents([.year, .month, .day], from: nextDate!)
        XCTAssertEqual(nextComponents.year, 2025)
        XCTAssertEqual(nextComponents.month, 5)
        XCTAssertEqual(nextComponents.day, 10)
    }
    
    func testInvalidRuleReturnsNil() {
        let now = Date()
        let nextDate = RecurrenceHelper.calculateNextDueDate(from: now, rule: "invalid_rule")
        XCTAssertNil(nextDate)
    }
    
    // MARK: - Description Tests
    
    func testDailyDescription() {
        let desc = RecurrenceHelper.description(for: "daily", date: Date())
        XCTAssertEqual(desc, "Reminds every day")
    }
    
    func testWeeklyDescription() {
        // Given a known Friday
        var components = DateComponents()
        components.year = 2024
        components.month = 12
        components.day = 27 // A Friday
        let date = Calendar.current.date(from: components)!
        
        let desc = RecurrenceHelper.description(for: "weekly", date: date)
        XCTAssertEqual(desc, "Reminds every Friday")
    }
}
