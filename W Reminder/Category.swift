//
//  Category.swift
//  W Reminder
//
//  Created by Suprawee Pongpeeradech on 11/20/25.
//

import SwiftUI

enum Category: String, CaseIterable, Identifiable, Codable {
    case work = "Work"
    case personal = "Personal"
    case shopping = "Shopping"
    case health = "Health"
    case finance = "Finance"
    case other = "Other"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .work: return .blue
        case .personal: return .green
        case .shopping: return .orange
        case .health: return .red
        case .finance: return .purple
        case .other: return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .work: return "briefcase.fill"
        case .personal: return "person.fill"
        case .shopping: return "cart.fill"
        case .health: return "heart.fill"
        case .finance: return "banknote.fill"
        case .other: return "tag.fill"
        }
    }
}
