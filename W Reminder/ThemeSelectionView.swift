import SwiftUI
import WidgetKit

struct ThemeSelectionView: View {
    @Binding var selectedThemeId: String
    let currentTheme: Theme
    
    var body: some View {
        List {
            ForEach(Theme.all) { option in
                Button {
                    withAnimation {
                        selectedThemeId = option.id
                    }
                } label: {
                    HStack(spacing: 16) {
                        themeSwatch(for: option)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(option.name)
                                .font(.headline)
                                .foregroundStyle(currentTheme.primary)
                            
                            if option.id == Theme.default.id {
                                Text("Default")
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(currentTheme.secondary.opacity(0.1))
                                    .clipShape(Capsule())
                                    .foregroundStyle(currentTheme.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if selectedThemeId == option.id {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(currentTheme.accent)
                        }
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(currentTheme.background.opacity(isDarkThemeRow(option) ? 0.3 : 0.6))
            }
        }
        .navigationTitle("Appearance")
        .scrollContentBackground(.hidden)
        .background(currentTheme.background.ignoresSafeArea())
    }
    
    private func themeSwatch(for theme: Theme) -> some View {
        HStack(spacing: -6) {
            Circle().fill(theme.primary).frame(width: 24, height: 24)
                .shadow(radius: 2)
            Circle().fill(theme.secondary).frame(width: 24, height: 24)
                .shadow(radius: 2)
            Circle().fill(theme.accent).frame(width: 24, height: 24)
                .shadow(radius: 2)
            Circle().fill(theme.background).frame(width: 24, height: 24)
                .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                .shadow(radius: 2)
        }
    }
    
    private func isDarkThemeRow(_ option: Theme) -> Bool {
        // Helper to adjust row contrast if needed
        return currentTheme.isDark
    }
}
