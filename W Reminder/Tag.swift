//
//  Tag.swift
//  W Reminder
//
//  Created by Suprawee Pongpeeradech on 11/20/25.
//

import SwiftUI
import SwiftData
import UIKit


@Model

final class Tag {
    var id: UUID = UUID()
    var name: String
    var colorHex: String
    var isTextWhite: Bool = false // User preference
    
    // Inverse relationship (optional but good for cascade delete if needed)
    // @Relationship(deleteRule: .nullify, inverse: \Checklist.tag) var checklists: [Checklist]

    @Relationship(inverse: \Checklist.tags) var checklists: [Checklist] = []
    @Relationship(inverse: \SimpleChecklist.tags) var simpleChecklists: [SimpleChecklist] = []

    init(id: UUID = UUID(), name: String, colorHex: String, isTextWhite: Bool = false) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.isTextWhite = isTextWhite
    }
    
    var color: Color {
        Color(hex: colorHex)
    }
    
    var textColor: Color {
        isTextWhite ? .white : .black
    }
}


