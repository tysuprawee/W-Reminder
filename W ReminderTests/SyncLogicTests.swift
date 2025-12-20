//
//  SyncLogicTests.swift
//  W ReminderTests
//
//  Created for Testing Sync Logic
//

import XCTest
import SwiftData
@testable import W_Reminder

@MainActor
final class SyncLogicTests: XCTestCase {

    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var syncManager: SyncManager!

    override func setUpWithError() throws {
        // Create an in-memory container for testing
        let schema = Schema([
            SimpleChecklist.self,
            Checklist.self,
            ChecklistItem.self,
            Tag.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [config])
        modelContext = modelContainer.mainContext
        
        syncManager = SyncManager.shared
        // In a real generic test, we might want to inject context or mock the manager, 
        // but since SyncManager uses 'shared', we just pass our test context to its methods.
    }

    override func tearDownWithError() throws {
        modelContainer = nil
        modelContext = nil
    }

    func testAddAndCleanLocalData() throws {
        // 1. Add some data
        let checklist = SimpleChecklist(title: "Test List", remind: false)
        modelContext.insert(checklist)
        
        let milestone = Checklist(title: "Test Milestone", remind: false)
        modelContext.insert(milestone)
        
        // Save
        try modelContext.save()
        
        // Verify exist
        var checklists = try modelContext.fetch(FetchDescriptor<SimpleChecklist>())
        var milestones = try modelContext.fetch(FetchDescriptor<Checklist>())
        XCTAssertEqual(checklists.count, 1)
        XCTAssertEqual(milestones.count, 1)
        
        // 2. Run Cleanup
        try syncManager.deleteLocalData(context: modelContext)
        
        // 3. Verify Empty
        checklists = try modelContext.fetch(FetchDescriptor<SimpleChecklist>())
        milestones = try modelContext.fetch(FetchDescriptor<Checklist>())
        
        XCTAssertTrue(checklists.isEmpty, "SimpleChecklists should be deleted")
        XCTAssertTrue(milestones.isEmpty, "Milestones should be deleted")
    }
    
    func testRegenerateIDs() throws {
        // 1. Create Data
        let originalID = UUID()
        let checklist = SimpleChecklist(title: "Merge Candidate", remind: false)
        checklist.id = originalID
        modelContext.insert(checklist)
        try modelContext.save()
        
        // 2. Regenerate
        try syncManager.regenerateIDs(context: modelContext)
        
        // 3. Verify
        let fetched = try modelContext.fetch(FetchDescriptor<SimpleChecklist>()).first
        XCTAssertNotNil(fetched)
        XCTAssertNotEqual(fetched?.id, originalID, "ID should have been regenerated")
    }
    
    func testHasLocalData() throws {
        // Should be false initially
        XCTAssertFalse(try syncManager.hasLocalData(context: modelContext))
        
        // Add data
        let tag = Tag(name: "Test Tag", colorHex: "#000000")
        modelContext.insert(tag)
        try modelContext.save()
        
        // Should be true
        XCTAssertTrue(try syncManager.hasLocalData(context: modelContext))
    }
}
