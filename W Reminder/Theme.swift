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

    static let dark = Theme(
        id: "dark",
        name: "Midnight Focus",
        primary: Color(hex: "#E0E0E0"),
        secondary: Color(hex: "#A0A0A0"),
        accent: Color(hex: "#7F5AF0"), // Purple accent
        background: Color(hex: "#16161A") // Dark background
    )

    static let pastelDream = Theme(
        id: "pastelDream",
        name: "Pastel Dream",
        primary: Color(hex: "#5D5D5D"),
        secondary: Color(hex: "#8E8E8E"),
        accent: Color(hex: "#FF8EAA"), // Pink
        background: Color(hex: "#FFF0F5") // Lavender Blush
    )

    static let mintFresh = Theme(
        id: "mintFresh",
        name: "Mint Fresh",
        primary: Color(hex: "#2D4436"),
        secondary: Color(hex: "#5C7A68"),
        accent: Color(hex: "#4ECDC4"), // Mint
        background: Color(hex: "#F0FFF4") // Honeydew
    )

    static let lavenderHaze = Theme(
        id: "lavenderHaze",
        name: "Lavender Haze",
        primary: Color(hex: "#4A4063"),
        secondary: Color(hex: "#786B94"),
        accent: Color(hex: "#B39DDB"), // Light Purple
        background: Color(hex: "#F3E5F5") // Purple 50
    )
    
    static let oceanic = Theme(
        id: "oceanic",
        name: "Oceanic",
        primary: Color(hex: "#E0F7FA"),
        secondary: Color(hex: "#B2EBF2"),
        accent: Color(hex: "#00BCD4"),
        background: Color(hex: "#006064") // Dark Cyan
    )

    static let all: [Theme] = [
        .classic,
        .warm,
        .dark,
        .pastelDream,
        .mintFresh,
        .lavenderHaze,
        .oceanic
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

    func toHex() -> String {
        let uic = UIColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else {
            return "#000000"
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        var a = Float(1.0)
        if components.count >= 4 {
            a = Float(components[3])
        }

        if a != Float(1.0) {
            return String(format: "#%02lX%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255), lroundf(a * 255))
        } else {
            return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        }
    }
}

