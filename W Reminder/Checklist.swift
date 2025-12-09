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
    var checklist: Checklist?
    var position: Int = 0

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
    var createdAt: Date = Date()
    var dueDate: Date?
    var remind: Bool = true
    var isDone: Bool = false
    var category: String? // Store raw value of Category enum
    @Relationship(deleteRule: .cascade, inverse: \ChecklistItem.checklist) var items: [ChecklistItem] = []

    init(
        title: String,
        notes: String? = nil,
        dueDate: Date? = nil,
        remind: Bool = true,
        items: [ChecklistItem] = [],
        category: Category? = nil
    ) {
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.remind = remind
        self.items = items
        self.category = category?.rawValue
    }
}

@Model
final class SimpleChecklist {
    var id: UUID = UUID()
    var title: String
    var notes: String?
    var createdAt: Date = Date()
    var dueDate: Date?
    var remind: Bool = true
    var isDone: Bool = false
    var category: String? // Store raw value of Category enum

    init(
        title: String,
        notes: String? = nil,
        dueDate: Date? = nil,
        remind: Bool = true,
        isDone: Bool = false,
        category: Category? = nil
    ) {
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.remind = remind
        self.isDone = isDone
        self.category = category?.rawValue
    }
}

