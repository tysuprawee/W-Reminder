
import SwiftUI
import Combine

@MainActor
class ThemeSelectionManager: ObservableObject {
    static let shared = ThemeSelectionManager()
    
    @AppStorage("selectedThemeId") var selectedThemeId: String = Theme.default.id
    
    var currentTheme: Theme {
        Theme.all.first { $0.id == selectedThemeId } ?? .default
    }
    
    // Function to switch theme
    func selectTheme(id: String) {
        withAnimation {
            selectedThemeId = id
        }
    }
}
