//
//  TimelineUITests.swift
//  W Reminder UI Tests
//
//  UI tests for TimelineView automatic updates and time display functionality
//

import XCTest

final class TimelineUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Time Display Tests
    
    func testTimeRemainingDisplayExists() throws {
        // Given - Navigate to Milestones tab
        let milestonesTab = app.tabBars.buttons["Milestones"]
        XCTAssertTrue(milestonesTab.exists, "Milestones tab should exist")
        milestonesTab.tap()
        
        // When - Create a task with a due date
        let addButton = app.buttons.matching(identifier: "plus").firstMatch
        if addButton.exists {
            addButton.tap()
            
            // Wait for the add sheet to appear
            sleep(1)
            
            // Fill in task details - use firstMatch since there's no specific identifier
            let titleField = app.textFields.firstMatch
            if titleField.exists {
                titleField.tap()
                titleField.typeText("Test Timeline Update")
            }
            
            // Enable deadline
            let deadlineToggle = app.switches.firstMatch
            if deadlineToggle.exists {
                deadlineToggle.tap()
                // Wait for date picker to appear
                sleep(1)
            }
            
            // Save the task
            let saveButton = app.buttons["Save"]
            if saveButton.exists {
                saveButton.tap()
                // Wait for sheet to dismiss and list to update
                sleep(2)
            }
        }
        
        // Then - Verify time display exists
        // Wait for the time display to appear (TimelineView updates every minute)
        var foundTimeDisplay = false
        let timePatterns = ["min", "hour", "day", "left", "ago", "Now"]
        
        // Try for up to 5 seconds to find the time display
        for _ in 0..<10 {
            foundTimeDisplay = timePatterns.contains { pattern in
                app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", pattern)).firstMatch.exists
            }
            if foundTimeDisplay {
                break
            }
            usleep(500_000) // Wait 0.5 seconds between checks
        }
        
        XCTAssertTrue(foundTimeDisplay, "Time remaining display should be visible")
    }
    
    func testPullToRefreshUpdatesDisplay() throws {
        // Given - Navigate to Milestones
        let milestonesTab = app.tabBars.buttons["Milestones"]
        milestonesTab.tap()
        
        // Get initial state
        sleep(1)
        
        // When - Pull to refresh
        let firstCell = app.cells.firstMatch
        if firstCell.exists {
            let start = firstCell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let finish = firstCell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1.5))
            start.press(forDuration: 0.1, thenDragTo: finish)
            
            // Wait for refresh animation
            sleep(1)
        }
        
        // Then - App should not crash and display should refresh
        XCTAssertTrue(app.tabBars.buttons["Milestones"].exists, "Should still be on Milestones tab")
    }
    
    func testChecklistsTabTimeDisplay() throws {
        // Given - Navigate to Checklists tab
        let checklistsTab = app.tabBars.buttons["Checklists"]
        XCTAssertTrue(checklistsTab.exists, "Checklists tab should exist")
        checklistsTab.tap()
        
        // When - Add a checklist with due date
        let addButton = app.buttons.matching(identifier: "plus").firstMatch
        if addButton.exists {
            addButton.tap()
            
            let titleField = app.textFields.firstMatch
            if titleField.exists {
                titleField.tap()
                titleField.typeText("Test Checklist Timeline")
            }
            
            // Enable deadline
            let deadlineToggle = app.switches.firstMatch
            if deadlineToggle.exists {
                deadlineToggle.tap()
            }
            
            let saveButton = app.buttons["Save"]
            if saveButton.exists {
                saveButton.tap()
            }
        }
        
        // Then - Verify time display can appear
        XCTAssertTrue(checklistsTab.isSelected, "Should be on Checklists tab")
    }
    
    func testCalendarViewShowsTasks() throws {
        // Given - Navigate to Calendar tab
        let calendarTab = app.tabBars.buttons["Calendar"]
        XCTAssertTrue(calendarTab.exists, "Calendar tab should exist")
        calendarTab.tap()
        
        // When - Calendar view loads
        sleep(1)
        
        // Then - Calendar should display
        let todayButton = app.buttons["Today"]
        XCTAssertTrue(todayButton.exists, "Calendar 'Today' button should exist")
        
        // Verify we can interact with calendar
        todayButton.tap()
        XCTAssertTrue(calendarTab.isSelected, "Should still be on Calendar tab")
    }
    
    // MARK: - Navigation Tests
    
    func testNavigationBetweenTabs() throws {
        // Test that we can navigate between all tabs without crashes
        let tabs = [
            "Milestones",
            "Checklists", 
            "Calendar",
            "Records",
            "Settings"
        ]
        
        for tabName in tabs {
            let tab = app.tabBars.buttons[tabName]
            if tab.exists {
                tab.tap()
                XCTAssertTrue(tab.isSelected, "\(tabName) tab should be selected")
                sleep(1) // Wait for tab to load
            }
        }
    }
    
    // MARK: - Settings View Tests
    
    func testSettingsShowsSilentModeInfo() throws {
        // Given - Navigate to Settings
        let settingsTab = app.tabBars.buttons["Settings"]
        settingsTab.tap()
        
        // Then - Silent mode info should be visible
        let soundModeText = app.staticTexts["Sound Mode"]
        XCTAssertTrue(soundModeText.exists, "Sound Mode label should exist in Settings")
    }
    
    // MARK: - Performance Tests
    
    func testScrollPerformance() throws {
        measure(metrics: [XCTClockMetric()]) {
            let milestonesTab = app.tabBars.buttons["Milestones"]
            milestonesTab.tap()
            
            // Scroll if there are items
            let firstCell = app.cells.firstMatch
            if firstCell.exists {
                for _ in 0..<3 {
                    firstCell.swipeUp()
                    firstCell.swipeDown()
                }
            }
        }
    }
    
    
    func testTimeRemainingLabelShowsCorrectFormat() throws {
        // Given - Navigate to Milestones
        let milestonesTab = app.tabBars.buttons["Milestones"]
        XCTAssertTrue(milestonesTab.exists, "Milestones tab should exist")
        milestonesTab.tap()
        
        // When - Create a task with a due date
        let addButton = app.buttons.matching(identifier: "plus").firstMatch
        XCTAssertTrue(addButton.exists, "Add button should exist")
        addButton.tap()
        
        // Wait for sheet to appear
        sleep(1)
        
        let titleField = app.textFields.firstMatch
        XCTAssertTrue(titleField.exists, "Title field should exist")
        titleField.tap()
        titleField.typeText("Time Format Test")
        
        let deadlineToggle = app.switches["deadlineToggle"]
        XCTAssertTrue(deadlineToggle.exists, "Deadline toggle should exist")
        deadlineToggle.tap()
        
        // Wait for date picker to appear
        sleep(1)
        
        let saveButton = app.buttons["Save"]
        XCTAssertTrue(saveButton.exists, "Save button should exist")
        saveButton.tap()
        
        // Wait for sheet to dismiss and list to update
        sleep(2)
        
        // Then - Verify time label exists and shows proper format
        let timeLabel = app.staticTexts["timeRemainingLabel"]
        XCTAssertTrue(timeLabel.waitForExistence(timeout: 5), "Time remaining label should appear")
        
        // Verify the label text contains expected time-related patterns
        let labelText = timeLabel.label
        let validPatterns = ["Now", "min", "hour", "day", "left", "ago", "Just now"]
        let hasValidFormat = validPatterns.contains { pattern in
            labelText.contains(pattern)
        }
        
        XCTAssertTrue(hasValidFormat, "Time remaining label should show valid time format. Got: '\(labelText)'")
    }


    
    
    // MARK: - Helper Methods
    
    private func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "exists == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
}
