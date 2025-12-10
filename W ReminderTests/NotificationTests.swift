//
//  NotificationTests.swift
//  W ReminderTests
//

import XCTest
import UserNotifications
@testable import W_Reminder

final class NotificationTests: XCTestCase {
    
    // MARK: - Notification Manager Tests
    
    func testNotificationManagerSharedInstance() {
        // Given/When
        let instance1 = NotificationManager.shared
        let instance2 = NotificationManager.shared
        
        // Then
        XCTAssertTrue(instance1 === instance2, "NotificationManager should be a singleton")
    }
    
    func testRequestAuthorizationCallsCompletion() {
        // Given
        let manager = NotificationManager.shared
        let expectation = expectation(description: "Authorization completion called")
        
        // When
        manager.requestAuthorization { granted in
            // Then - completion should be called
            expectation.fulfill()
        }
        
        // Wait for async completion
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testCancelNotificationForChecklist() {
        // Given
        let manager = NotificationManager.shared
        let checklist = Checklist(
            title: "Test Checklist",
            notes: "Test notes",
            dueDate: Date().addingTimeInterval(3600),
            remind: true
        )
        
        // When/Then - should not crash
        manager.cancelNotification(for: checklist)
        XCTAssertTrue(true, "Cancel notification should execute without error")
    }
    
    func testCancelNotificationForSimpleChecklist() {
        // Given
        let manager = NotificationManager.shared
        let checklist = SimpleChecklist(
            title: "Test Simple",
            notes: "Test notes",
            dueDate: Date().addingTimeInterval(3600),
            remind: true
        )
        
        // When/Then - should not crash  
        manager.cancelNotification(for: checklist)
        XCTAssertTrue(true, "Cancel notification should execute without error")
    }
    
    // MARK: - Notification Sound Tests
    
    func testNotificationSoundDefaultHasNoFileName() {
        // Given
        let sound = NotificationSound.default
        
        // Then
        XCTAssertNil(sound.fileName, "Default sound should not have a custom file name")
    }
    
    func testNotificationSoundBellHasFileName() {
        // Given
        let sound = NotificationSound.bell
        
        // Then
        XCTAssertEqual(sound.fileName, "bell.caf")
    }
    
    func testNotificationSoundEnumCaseCount() {
        // When
        let allCases = NotificationSound.allCases
        
        // Then
        XCTAssertEqual(allCases.count, 5, "Should have exactly 5 sound options")
    }
    
    func testNotificationSoundRawValues() {
        // Then
        XCTAssertEqual(NotificationSound.default.rawValue, "Default")
        XCTAssertEqual(NotificationSound.bell.rawValue, "Bell")
        XCTAssertEqual(NotificationSound.chime.rawValue, "Chime")
        XCTAssertEqual(NotificationSound.alert.rawValue, "Alert")
        XCTAssertEqual(NotificationSound.ping.rawValue, "Ping")
    }
    
    func testNotificationSoundIdentifiable() {
        // Given
        let sound = NotificationSound.chime
        
        // Then
        XCTAssertEqual(sound.id, sound.rawValue, "ID should match raw value")
    }
}
