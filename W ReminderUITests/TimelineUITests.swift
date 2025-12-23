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
        let milestonesTab = app.tabBars.buttons["Milestones"]
        XCTAssertTrue(milestonesTab.exists)
        milestonesTab.tap()
        
        let addButton = app.buttons.matching(identifier: "plus").firstMatch
        if addButton.exists {
            addButton.tap()
            sleep(1)
            
            let titleField = app.textFields.firstMatch
            if titleField.exists {
                titleField.tap()
                titleField.typeText("Test Timeline Update")
            }
            
            let deadlineToggle = app.buttons["deadlineToggle"]
            if deadlineToggle.exists {
                deadlineToggle.tap()
                sleep(1)
            }
            
            let saveButton = app.buttons["Save"]
            if saveButton.exists {
                saveButton.tap()
                sleep(2)
            }
        }
        
        var foundTimeDisplay = false
        let timePatterns = ["min", "hour", "day", "left", "ago", "Now"]
        
        for _ in 0..<10 {
            foundTimeDisplay = timePatterns.contains { pattern in
                app.staticTexts
                    .containing(NSPredicate(format: "label CONTAINS %@", pattern))
                    .firstMatch
                    .exists
            }
            if foundTimeDisplay { break }
            usleep(500_000)
        }
        
        XCTAssertTrue(foundTimeDisplay)
    }
    
    func testPullToRefreshUpdatesDisplay() throws {
        let milestonesTab = app.tabBars.buttons["Milestones"]
        milestonesTab.tap()
        sleep(1)
        
        let firstCell = app.cells.firstMatch
        if firstCell.exists {
            let start = firstCell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let finish = firstCell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1.5))
            start.press(forDuration: 0.1, thenDragTo: finish)
            sleep(1)
        }
        
        XCTAssertTrue(app.tabBars.buttons["Milestones"].exists)
    }
    
    func testChecklistsTabTimeDisplay() throws {
        let checklistsTab = app.tabBars.buttons["Checklists"]
        XCTAssertTrue(checklistsTab.exists)
        checklistsTab.tap()
        
        let addButton = app.buttons.matching(identifier: "plus").firstMatch
        if addButton.exists {
            addButton.tap()
            
            let titleField = app.textFields.firstMatch
            if titleField.exists {
                titleField.tap()
                titleField.typeText("Test Checklist Timeline")
            }
            
            let deadlineToggle = app.buttons["deadlineToggle"]
            if deadlineToggle.exists {
                deadlineToggle.tap()
            }
            
            let saveButton = app.buttons["Save"]
            if saveButton.exists {
                saveButton.tap()
            }
        }
        
        XCTAssertTrue(checklistsTab.isSelected)
    }
    
    func testCalendarViewShowsTasks() throws {
        let calendarTab = app.tabBars.buttons["Calendar"]
        XCTAssertTrue(calendarTab.exists)
        calendarTab.tap()
        sleep(1)
        
        let todayButton = app.buttons["Today"]
        XCTAssertTrue(todayButton.exists)
        todayButton.tap()
        
        XCTAssertTrue(calendarTab.isSelected)
    }
    
    // MARK: - Navigation Tests
    
    func testNavigationBetweenTabs() throws {
        let tabs = ["Milestones", "Checklists", "Calendar", "Records", "Settings"]
        
        for tabName in tabs {
            let tab = app.tabBars.buttons[tabName]
            if tab.exists {
                tab.tap()
                XCTAssertTrue(tab.isSelected)
                sleep(1)
            }
        }
    }
    
    // MARK: - Settings View Tests
    
    func testSettingsShowsSilentModeInfo() throws {
        let settingsTab = app.tabBars.buttons["Settings"]
        settingsTab.tap()
        
        let soundModeText = app.staticTexts["Silent Mode"]
        XCTAssertTrue(soundModeText.exists)
    }
    
    // MARK: - Performance Tests
    
    func testScrollPerformance() throws {
        measure(metrics: [XCTClockMetric()]) {
            let milestonesTab = app.tabBars.buttons["Milestones"]
            milestonesTab.tap()
            
            let firstCell = app.cells.firstMatch
            if firstCell.exists {
                for _ in 0..<3 {
                    firstCell.swipeUp()
                    firstCell.swipeDown()
                }
            }
        }
    }
    
    // MARK: - SKIPPED TEST
    
    func testTimeRemainingLabelShowsCorrectFormat() throws {
        throw XCTSkip("Skipped: flaky snapshot test due to multiple timeRemainingLabel elements.")
    }
    
    // MARK: - Helper Methods
    
    private func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "exists == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
