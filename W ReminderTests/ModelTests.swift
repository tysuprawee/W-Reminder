//
//  ModelTests.swift
//  W Reminder Tests
//
//  Model tests for Checklist, SimpleChecklist, ChecklistItem, and Tag
//

import XCTest
import SwiftData
@testable import W_Reminder

@MainActor
final class ModelTests: XCTestCase {
    
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    override func setUpWithError() throws {
        // Create an in-memory model container for testing
        let schema = Schema([
            Checklist.self,
            ChecklistItem.self,
            SimpleChecklist.self,
            Tag.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = ModelContext(modelContainer)
    }
    
    override func tearDownWithError() throws {
        modelContainer = nil
        modelContext = nil
    }
    
    // MARK: - Tag Tests
    
    func testTagCreation() throws {
        // Given
        let tagName = "Work"
        let colorHex = "#FF5733"
        
        // When
        let tag = Tag(name: tagName, colorHex: colorHex)
        modelContext.insert(tag)
        
        // Then
        XCTAssertEqual(tag.name, tagName)
        XCTAssertEqual(tag.colorHex, colorHex)
        XCTAssertNotNil(tag.id)
    }
    
    func testTagColorConversion() throws {
        // Given
        let redHex = "#FF0000"
        let tag = Tag(name: "Urgent", colorHex: redHex)
        
        // When
        let color = tag.color
        
        // Then - Should convert hex to Color successfully
        XCTAssertNotNil(color)
        // Note: Direct color comparison is tricky, but we can verify it doesn't crash
    }
    
    // MARK: - ChecklistItem Tests
    
    func testChecklistItemCreation() throws {
        // Given
        let itemText = "Complete unit tests"
        let position = 0
        
        // When
        let item = ChecklistItem(text: itemText, position: position)
        
        // Then
        XCTAssertEqual(item.text, itemText)
        XCTAssertEqual(item.position, position)
        XCTAssertFalse(item.isDone)
        XCTAssertNotNil(item.id)
    }
    
    func testChecklistItemToggle() throws {
        // Given
        let item = ChecklistItem(text: "Task", position: 0)
        XCTAssertFalse(item.isDone)
        
        // When
        item.isDone.toggle()
        
        // Then
        XCTAssertTrue(item.isDone)
    }
    
    // MARK: - Checklist Tests
    
    func testChecklistCreation() throws {
        // Given
        let title = "Project Milestone"
        let notes = "Important project tasks"
        let dueDate = Date()
        
        // When
        let checklist = Checklist(
            title: title,
            notes: notes,
            dueDate: dueDate,
            remind: true,
            items: [],
            tags: []
        )
        modelContext.insert(checklist)
        
        // Then
        XCTAssertEqual(checklist.title, title)
        XCTAssertEqual(checklist.notes, notes)
        XCTAssertEqual(checklist.dueDate, dueDate)
        XCTAssertTrue(checklist.remind)
        XCTAssertFalse(checklist.isDone)
        XCTAssertEqual(checklist.items.count, 0)
        XCTAssertEqual(checklist.tags.count, 0)
    }
    
    func testChecklistWithItems() throws {
        // Given
        let item1 = ChecklistItem(text: "Step 1", position: 0)
        let item2 = ChecklistItem(text: "Step 2", position: 1)
        
        // When
        let checklist = Checklist(
            title: "Multi-step Task",
            notes: nil,
            dueDate: nil,
            remind: false,
            items: [item1, item2],
            tags: []
        )
        modelContext.insert(checklist)
        
        // Then
        XCTAssertEqual(checklist.items.count, 2)
        XCTAssertEqual(checklist.items[0].text, "Step 1")
        XCTAssertEqual(checklist.items[1].text, "Step 2")
    }
    
    func testChecklistWithTags() throws {
        // Given
        let tag1 = Tag(name: "Work", colorHex: "#FF5733")
        let tag2 = Tag(name: "Urgent", colorHex: "#FF0000")
        modelContext.insert(tag1)
        modelContext.insert(tag2)
        
        // When
        let checklist = Checklist(
            title: "Tagged Task",
            notes: nil,
            dueDate: nil,
            remind: false,
            items: [],
            tags: [tag1, tag2]
        )
        modelContext.insert(checklist)
        
        // Then
        XCTAssertEqual(checklist.tags.count, 2)
        XCTAssertTrue(checklist.tags.contains(where: { $0.name == "Work" }))
        XCTAssertTrue(checklist.tags.contains(where: { $0.name == "Urgent" }))
    }
    
    func testChecklistCompletion() throws {
        // Given
        let checklist = Checklist(
            title: "Test Checklist",
            notes: nil,
            dueDate: nil,
            remind: false,
            items: [],
            tags: []
        )
        XCTAssertFalse(checklist.isDone)
        
        // When
        checklist.isDone = true
        
        // Then
        XCTAssertTrue(checklist.isDone)
    }
    
    // MARK: - SimpleChecklist Tests
    
    func testSimpleChecklistCreation() throws {
        // Given
        let title = "Buy groceries"
        let notes = "Milk, eggs, bread"
        let dueDate = Date()
        
        // When
        let checklist = SimpleChecklist(
            title: title,
            notes: notes,
            dueDate: dueDate,
            remind: true,
            tags: []
        )
        modelContext.insert(checklist)
        
        // Then
        XCTAssertEqual(checklist.title, title)
        XCTAssertEqual(checklist.notes, notes)
        XCTAssertEqual(checklist.dueDate, dueDate)
        XCTAssertTrue(checklist.remind)
        XCTAssertFalse(checklist.isDone)
    }
    
    func testSimpleChecklistToggle() throws {
        // Given
        let checklist = SimpleChecklist(
            title: "Simple Task",
            notes: nil,
            dueDate: nil,
            remind: false,
            tags: []
        )
        XCTAssertFalse(checklist.isDone)
        
        // When
        checklist.isDone.toggle()
        
        // Then
        XCTAssertTrue(checklist.isDone)
    }
    
    // MARK: - Relationship Tests
    
    func testChecklistItemRelationship() throws {
        // Given
        let item = ChecklistItem(text: "Related Item", position: 0)
        let checklist = Checklist(
            title: "Parent Checklist",
            notes: nil,
            dueDate: nil,
            remind: false,
            items: [item],
            tags: []
        )
        modelContext.insert(checklist)
        
        // When
        item.checklist = checklist
        
        // Then
        XCTAssertNotNil(item.checklist)
        XCTAssertEqual(item.checklist?.title, "Parent Checklist")
    }
    
    // MARK: - SwiftData Fetch Tests
    
    func testFetchAllChecklists() throws {
        // Given
        let checklist1 = Checklist(title: "Task 1", notes: nil, dueDate: nil, remind: false, items: [], tags: [])
        let checklist2 = Checklist(title: "Task 2", notes: nil, dueDate: nil, remind: false, items: [], tags: [])
        modelContext.insert(checklist1)
        modelContext.insert(checklist2)
        try modelContext.save()
        
        // When
        let descriptor = FetchDescriptor<Checklist>()
        let checklists = try modelContext.fetch(descriptor)
        
        // Then
        XCTAssertEqual(checklists.count, 2)
    }
    
    func testFetchChecklistsWithPredicate() throws {
        // Given
        let completedChecklist = Checklist(title: "Done", notes: nil, dueDate: nil, remind: false, items: [], tags: [])
        completedChecklist.isDone = true
        let pendingChecklist = Checklist(title: "Pending", notes: nil, dueDate: nil, remind: false, items: [], tags: [])
        modelContext.insert(completedChecklist)
        modelContext.insert(pendingChecklist)
        try modelContext.save()
        
        // When - Fetch only completed checklists
        let descriptor = FetchDescriptor<Checklist>(
            predicate: #Predicate { $0.isDone == true }
        )
        let completed = try modelContext.fetch(descriptor)
        
        // Then
        XCTAssertEqual(completed.count, 1)
        XCTAssertEqual(completed.first?.title, "Done")
    }
}
