//
//  Checklist.swift
//  W Reminder
//

import Foundation
import SwiftData

@Model
final class ChecklistItem {
    var id: UUID = UUID()
    var text: String
    var isDone: Bool = false
    var position: Int
    
    var checklist: Checklist? // Inverse relationship

    init(text: String, isDone: Bool = false, position: Int = 0) {
        self.text = text
        self.isDone = isDone
        self.position = position
    }
}

@Model
final class Checklist {
    var id: UUID = UUID()
    var title: String
    var notes: String?
    var createdAt: Date
    var dueDate: Date?
    var remind: Bool
    var isDone: Bool = false
    
    @Relationship(deleteRule: .cascade, inverse: \ChecklistItem.checklist) var items: [ChecklistItem] = []
    
    // Updated: Use helper or just manual check for "overdue".
    // Computed properties are not persisted but useful in views.
    
    @Relationship var tag: Tag?

    init(
        title: String,
        notes: String? = nil,
        dueDate: Date? = nil,
        remind: Bool = false,
        items: [ChecklistItem] = [],
        tag: Tag? = nil
    ) {
        self.title = title
        self.notes = notes
        self.createdAt = Date()
        self.dueDate = dueDate
        self.remind = remind
        self.items = items
        self.tag = tag
    }
}

@Model
final class SimpleChecklist {
    var id: UUID = UUID()
    var title: String
    var notes: String?
    var createdAt: Date
    var dueDate: Date?
    var remind: Bool
    var isDone: Bool = false
    
    @Relationship var tag: Tag?

    init(
        title: String,
        notes: String? = nil,
        dueDate: Date? = nil,
        remind: Bool = false,
        isDone: Bool = false, // Keep this parameter as it was in the original SimpleChecklist init
        tag: Tag? = nil
    ) {
        self.title = title
        self.notes = notes
        self.createdAt = Date()
        self.dueDate = dueDate
        self.remind = remind
        self.isDone = isDone // Assign the parameter
        self.tag = tag
    }
}
