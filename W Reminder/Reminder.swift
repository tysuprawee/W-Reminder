//
//  Reminder.swift
//  W Reminder
//

import Foundation
import SwiftData

@Model
final class Reminder {
    var id: UUID       
    var title: String
    var dueDate: Date
    var notes: String?

    init(
        id: UUID = UUID(),
        title: String,
        dueDate: Date,
        notes: String? = nil
    ) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.notes = notes
    }
}
