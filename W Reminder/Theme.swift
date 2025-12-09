//
//  Theme.swift
//  W Reminder
//

import SwiftUI

struct Theme: Identifiable, Hashable {
    let id: String
    let name: String
    let primary: Color
    let secondary: Color
    let accent: Color
    let background: Color

    static let classic = Theme(
        id: "classic",
        name: "Classic Calm",
        primary: Color(hex: "#313647"),
        secondary: Color(hex: "#435663"),
        accent: Color(hex: "#A3B087"),
        background: Color(hex: "#FFF8D4")
    )

    static let warm = Theme(
        id: "warm",
        name: "Warm Focus",
        primary: Color(hex: "#7B542F"),
        secondary: Color(hex: "#B6771D"),
        accent: Color(hex: "#FF9D00"),
        background: Color(hex: "#FFCF71")
    )

    static let all: [Theme] = [
        .classic,
        .warm
    ]

    static let `default` = classic
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

