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
    let isDark: Bool
    // New Unlock Requirement
    let unlockRequirement: ThemeUnlockRequirement?

    enum ThemeUnlockRequirement: Hashable {
        case level(Int)
        case invites(Int)
        case streak(Int) // New Streak Requirement
        case premium
        
        var description: String {
            switch self {
            case .level(let l): return "Reach Level \(l)"
            case .invites(let i): return "Invite \(i) Friends"
            case .streak(let s): return "\(s)-Day Streak"
            case .premium: return "Premium Only"
            }
        }
    }

    static let classic = Theme(
        id: "classic",
        name: "Classic Calm",
        primary: Color(hex: "#2C3E50"),
        secondary: Color(hex: "#5D6D7E"),
        accent: Color(hex: "#6B8E23"),
        background: Color(hex: "#FFF8D4"),
        isDark: false,
        unlockRequirement: nil // Unlocked 1
    )

    static let warm = Theme(
        id: "warm",
        name: "Warm Focus",
        primary: Color(hex: "#5D4037"),
        secondary: Color(hex: "#8D6E63"),
        accent: Color(hex: "#D84315"),
        background: Color(hex: "#FFE0B2"),
        isDark: false,
        unlockRequirement: nil // Unlocked 2
    )

    static let dark = Theme(
        id: "dark",
        name: "Midnight Focus",
        primary: Color(hex: "#F5F5F5"),
        secondary: Color(hex: "#BDBDBD"),
        accent: Color(hex: "#BB86FC"),
        background: Color(hex: "#121212"),
        isDark: true,
        unlockRequirement: .level(3) // Easy
    )

    static let pastelDream = Theme(
        id: "pastelDream",
        name: "Pastel Dream",
        primary: Color(hex: "#4A4A4A"),
        secondary: Color(hex: "#757575"),
        accent: Color(hex: "#D81B60"),
        background: Color(hex: "#FFF0F5"),
        isDark: false,
        unlockRequirement: .streak(3) // Easy
    )

    static let mintFresh = Theme(
        id: "mintFresh",
        name: "Mint Fresh",
        primary: Color(hex: "#1B5E20"),
        secondary: Color(hex: "#388E3C"),
        accent: Color(hex: "#00897B"),
        background: Color(hex: "#E8F5E9"),
        isDark: false,
        unlockRequirement: .level(5) // Easy
    )

    static let lavenderHaze = Theme(
        id: "lavenderHaze",
        name: "Lavender Haze",
        primary: Color(hex: "#4A4063"),
        secondary: Color(hex: "#673AB7"),
        accent: Color(hex: "#7E57C2"),
        background: Color(hex: "#F3E5F5"),
        isDark: false,
        unlockRequirement: .invites(1) // First Invite
    )
    
    static let oceanic = Theme(
        id: "oceanic",
        name: "Oceanic",
        primary: Color(hex: "#E0F7FA"),
        secondary: Color(hex: "#80DEEA"),
        accent: Color(hex: "#00E5FF"),
        background: Color(hex: "#006064"),
        isDark: true,
        unlockRequirement: .streak(7) // Week Warrior
    )

    static let sunsetGlow = Theme(
        id: "sunsetGlow",
        name: "Sunset Glow",
        primary: Color(hex: "#3E2723"),
        secondary: Color(hex: "#D84315"),
        accent: Color(hex: "#FF6F00"),
        background: Color(hex: "#FFCCBC"),
        isDark: false,
        unlockRequirement: .invites(3)
    )

    static let forestDeep = Theme(
        id: "forestDeep",
        name: "Forest Deep",
        primary: Color(hex: "#E8F5E9"),
        secondary: Color(hex: "#A5D6A7"),
        accent: Color(hex: "#66BB6A"),
        background: Color(hex: "#1B5E20"),
        isDark: true,
        unlockRequirement: .level(20)
    )

    static let royalGold = Theme(
        id: "royalGold",
        name: "Royal Gold",
        primary: Color(hex: "#FFF8E1"),
        secondary: Color(hex: "#FFECB3"),
        accent: Color(hex: "#FFC107"),
        background: Color(hex: "#311B92"),
        isDark: true,
        unlockRequirement: .streak(30) // Monthly Legend
    )

    static let charcoal = Theme(
        id: "charcoal",
        name: "Modern Charcoal",
        primary: Color(hex: "#ECEFF1"),
        secondary: Color(hex: "#CFD8DC"),
        accent: Color(hex: "#00BCD4"),
        background: Color(hex: "#263238"),
        isDark: true,
        unlockRequirement: .invites(5)
    )

    static let skyBlue = Theme(
        id: "skyBlue",
        name: "Sky High",
        primary: Color(hex: "#01579B"),
        secondary: Color(hex: "#0288D1"),
        accent: Color(hex: "#29B6F6"),
        background: Color(hex: "#E1F5FE"),
        isDark: false,
        unlockRequirement: .level(10)
    )
    
    // INVITE THEME (Influencer)
    static let influencer = Theme(
        id: "influencer",
        name: "Influencer Gold",
        primary: Color(hex: "#FFFDE7"),
        secondary: Color(hex: "#FFD54F"),
        accent: Color(hex: "#FFAB00"),
        background: Color(hex: "#212121"),
        isDark: true,
        unlockRequirement: .invites(15) // Max Invite Challenge
    )

    static let all: [Theme] = [
        .classic,
        .warm,
        .dark,
        .pastelDream,
        .skyBlue,
        .mintFresh,
        .lavenderHaze,
        .oceanic,
        .sunsetGlow,
        .forestDeep,
        .royalGold,
        .charcoal,
        .influencer
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

