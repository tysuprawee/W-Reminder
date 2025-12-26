
import SwiftUI
import Combine

@MainActor
class ThemeSelectionManager: ObservableObject {
    static let shared = ThemeSelectionManager()
    
    @AppStorage("selectedThemeId") var selectedThemeId: String = Theme.default.id
    
    // Track when user locally changes theme to prevent fighting with Cloud echoes
    var lastLocalUpdate: Date = .distantPast
    
    var currentTheme: Theme {
        Theme.all.first { $0.id == selectedThemeId } ?? .default
    }
    
    // Function to switch theme
    func selectTheme(id: String) {
        lastLocalUpdate = Date()
        withAnimation {
            selectedThemeId = id
        }
    }
    
    func resetToDefault() {
        lastLocalUpdate = Date()
        withAnimation {
            selectedThemeId = Theme.default.id
        }
    }
}
