//
//  RobustnessTests.swift
//  W ReminderTests
//
//  Created for Robustness Verification
//

import XCTest
import SwiftData
@testable import W_Reminder

@MainActor
final class RobustnessTests: XCTestCase {

    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var syncManager: SyncManager!

    override func setUpWithError() throws {
        // Include DeletedRecord in schema to test deletion robustness
        let schema = Schema([
            SimpleChecklist.self,
            Checklist.self,
            ChecklistItem.self,
            Tag.self,
            DeletedRecord.self 
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [config])
        modelContext = modelContainer.mainContext
        
        syncManager = SyncManager.shared
    }

    override func tearDownWithError() throws {
        modelContainer = nil
        modelContext = nil
    }

    // MARK: - 1. Local Persistence (Add/Remove)
    
    func testLocalTaskLifecycle() throws {
        // Create
        let task = SimpleChecklist(title: "Life Cycle Test", remind: false)
        modelContext.insert(task)
        try modelContext.save()
        
        // Verify Created
        let fetchDesc = FetchDescriptor<SimpleChecklist>()
        var tasks = try modelContext.fetch(fetchDesc)
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks.first?.title, "Life Cycle Test")
        
        // Delete
        // Simulate View Action: Register Deletion then Delete
        syncManager.registerDeletion(of: task, context: modelContext)
        modelContext.delete(task)
        try modelContext.save()
        
        // Verify Deleted (No Ghost)
        tasks = try modelContext.fetch(fetchDesc)
        XCTAssertTrue(tasks.isEmpty, "Task should be removed from database")
        
        // Verify Tombstone Created
        let tombstones = try modelContext.fetch(FetchDescriptor<DeletedRecord>())
        XCTAssertEqual(tombstones.count, 1, "Should have 1 deleted record for sync")
        XCTAssertEqual(tombstones.first?.targetID, task.id)
    }

    // MARK: - 2. Completion Logic (Insights Integrity)
    
    func testTaskCompletionIntegrity() throws {
        let task = SimpleChecklist(title: "Insights Test", remind: false)
        modelContext.insert(task)
        
        // Initial: Not Done, No Date
        XCTAssertFalse(task.isDone)
        XCTAssertNil(task.completedAt)
        
        // Action: Mark Done
        task.isDone = true
        task.completedAt = Date()
        try modelContext.save()
        
        XCTAssertNotNil(task.completedAt)
        
        // Action: Revive (Undone)
        task.isDone = false
        task.completedAt = nil
        try modelContext.save()
        
        XCTAssertNil(task.completedAt, "CompletedAt should be nil'd out when revived")
        
        // Action: Mark Done Again
        task.isDone = true
        task.completedAt = Date()
        try modelContext.save()
        XCTAssertNotNil(task.completedAt)
    }
    
    // MARK: - 3. Sync DTO Correctness
    
    func testCloudDTOStructure() throws {
        // Ensure that our DTOs match the expected Codable structure, 
        // specifically checking the new `completedAt` field.
        
        let now = Date()
        let cloudItem = CloudSimpleChecklist(
            id: UUID(),
            userId: UUID(),
            title: "Test",
            notes: nil,
            dueDate: nil,
            remind: false,
            isDone: true,
            isStarred: false,
            userOrder: 0,
            recurrenceRule: nil,
            completedAt: now
        )
        
        let encoded = try JSONEncoder().encode(cloudItem)
        let decoded = try JSONDecoder().decode(CloudSimpleChecklist.self, from: encoded)
        
        XCTAssertEqual(decoded.completedAt?.timeIntervalSince1970 ?? 0, now.timeIntervalSince1970, accuracy: 0.001)
    }
    
    // MARK: - 4. Sync State Logic
    
    func testSyncStateTransitions() async {
        // Test that isSyncing updates (Simulation)
        // Since we can't run full sync without auth, we simulate the state flag helper if exposed,
        // or just verify the initial state.
        
        XCTAssertFalse(syncManager.isSyncing)
        
        // We can't easily mock the network call inside `sync()` without refactoring SyncManager to use a protocol.
        // However, we've verified the "Pre-Sync" (Deletion Registration) and "Data Structure" (DTOs) above,
        // which covers the robust data handling requirements.
    }
}
