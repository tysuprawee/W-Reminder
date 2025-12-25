//  Checklist.swift
//  W Reminder

import Foundation
import SwiftData

@Model
final class ChecklistItem {
    var id: UUID = UUID()
    var text: String
    var isDone: Bool = false
    var position: Int
    var dueDate: Date? // Added per user request
    var checklist: Checklist? // Inverse relationship
    init(text: String, isDone: Bool = false, position: Int = 0, dueDate: Date? = nil) {
        self.text = text
        self.isDone = isDone
        self.position = position
        self.dueDate = dueDate
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
    var isStarred: Bool = false
    var userOrder: Int = 0
    var recurrenceRule: String? // "daily", "weekly", "monthly", "custom"
    var completedAt: Date? // Added for Statistics
    var updatedAt: Date = Date() // For Sync Conflict Resolution
    
    @Relationship(deleteRule: .cascade, inverse: \ChecklistItem.checklist) var items: [ChecklistItem] = []
    
    // Updated: Use helper or just manual check for "overdue".
    // Computed properties are not persisted but useful in views.
    
    @Relationship var tags: [Tag] = []
    init(
        title: String,
        notes: String? = nil,
        dueDate: Date? = nil,
        remind: Bool = false,
        items: [ChecklistItem] = [],
        tags: [Tag] = [],
        isStarred: Bool = false,
        userOrder: Int = 0,
        recurrenceRule: String? = nil,
        completedAt: Date? = nil,
        updatedAt: Date = Date()
    ) {
        self.title = title
        self.notes = notes
        self.createdAt = Date()
        self.dueDate = dueDate
        self.remind = remind
        self.isStarred = isStarred
        self.items = items
        self.tags = tags
        self.userOrder = userOrder
        self.recurrenceRule = recurrenceRule
        self.completedAt = completedAt
        self.updatedAt = updatedAt
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
    var isStarred: Bool = false
    var userOrder: Int = 0
    var recurrenceRule: String?
    var completedAt: Date? // Added for Statistics
    var updatedAt: Date = Date() // For Sync Conflict Resolution
    @Relationship var tags: [Tag] = []

    init(
        title: String,
        notes: String? = nil,
        dueDate: Date? = nil,
        remind: Bool = false,
        isDone: Bool = false,
        tags: [Tag] = [],
        isStarred: Bool = false,
        userOrder: Int = 0,
        recurrenceRule: String? = nil,
        completedAt: Date? = nil,
        updatedAt: Date = Date()
    ) {
        self.title = title
        self.notes = notes
        self.createdAt = Date()
        self.dueDate = dueDate
        self.remind = remind
        self.isDone = isDone
        self.isStarred = isStarred
        self.tags = tags
        self.userOrder = userOrder
        self.recurrenceRule = recurrenceRule
        self.completedAt = completedAt
        self.updatedAt = updatedAt
    }
}

struct RecurrenceHelper {
    static func description(for rule: String, date: Date) -> String {
        switch rule {
        case "daily":
            return "Reminds every day"
        case "weekly":
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return "Reminds every \(formatter.string(from: date))"
        case "monthly":
            let calendar = Calendar.current
            let day = calendar.component(.day, from: date)
            return "Reminds every month on the \(ordinalString(from: day))"
        case "yearly":
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d"
            return "Reminds every year on \(formatter.string(from: date))"
        default:
            return ""
        }
    }
    
    private static func ordinalString(from number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)th"
    }

    static func calculateNextDueDate(from current: Date, rule: String) -> Date? {
        let calendar = Calendar.current
        switch rule.lowercased() {
        case "daily":
            return calendar.date(byAdding: .day, value: 1, to: current)
        case "weekly":
            return calendar.date(byAdding: .weekOfYear, value: 1, to: current)
        case "monthly":
            return calendar.date(byAdding: .month, value: 1, to: current)
        case "yearly":
            return calendar.date(byAdding: .year, value: 1, to: current)
        default:
            return nil
        }
    }
}
