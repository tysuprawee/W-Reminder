//
//  Tag.swift
//  W Reminder
//
//  Created by Suprawee Pongpeeradech on 11/20/25.
//

import SwiftUI
import SwiftData

@Model

final class Tag {
    var id: UUID = UUID()
    var name: String
    var colorHex: String
    
    // Inverse relationship (optional but good for cascade delete if needed)
    // @Relationship(deleteRule: .nullify, inverse: \Checklist.tag) var checklists: [Checklist]

    @Relationship(inverse: \Checklist.tags) var checklists: [Checklist] = []
    @Relationship(inverse: \SimpleChecklist.tags) var simpleChecklists: [SimpleChecklist] = []

    init(id: UUID = UUID(), name: String, colorHex: String) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
    }
    
    var color: Color {
        Color(hex: colorHex)
    }
}
