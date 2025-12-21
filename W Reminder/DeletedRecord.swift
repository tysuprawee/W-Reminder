//
//  DeletedRecord.swift
//  W Reminder
//
//  Created for Sync Deletion Tracking
//

import Foundation
import SwiftData

@Model
final class DeletedRecord {
    var id: UUID = UUID()
    var targetID: UUID
    var table: String // "milestones", "simple_checklists", "tags"
    var deletedAt: Date
    
    init(targetID: UUID, table: String) {
        self.targetID = targetID
        self.table = table
        self.deletedAt = Date()
    }
}
