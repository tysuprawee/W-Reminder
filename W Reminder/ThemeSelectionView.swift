import SwiftUI
import WidgetKit

struct ThemeSelectionView: View {
    @Binding var selectedThemeId: String
    let currentTheme: Theme
    
    @State private var previewTheme: Theme? // For the preview sheet

    var body: some View {
        List {
            ForEach(Theme.all) { option in
                let (isLocked, requirementText) = checkLockStatus(for: option)
                
                HStack(spacing: 12) {
                    // 1. Selection Button Area (Leading)
                    Button {
                        if !isLocked {
                            withAnimation {
                                selectedThemeId = option.id
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            themeSwatch(for: option)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(option.name)
                                    .font(.headline)
                                    .foregroundStyle(currentTheme.primary) // Always visible
                                
                                if isLocked {
                                    HStack(spacing: 6) {
                                        Image(systemName: "lock.fill")
                                            .font(.caption2)
                                        Text(requirementText)
                                            .font(.caption)
                                            .bold()
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundStyle(.orange)
                                    .clipShape(Capsule())
                                } else if option.id == Theme.default.id {
                                    Text("Default")
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(currentTheme.secondary.opacity(0.1))
                                        .clipShape(Capsule())
                                        .foregroundStyle(currentTheme.secondary)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isLocked)
                    
                    Spacer()
                    
                    // 2. Trailing Actions: Preview & Checkmark
                    HStack(spacing: 16) {
                        Button {
                            previewTheme = option
                        } label: {
                            Image(systemName: "eye.fill")
                                .font(.title3)
                                .foregroundStyle(currentTheme.secondary)
                        }
                        .buttonStyle(.plain)
                        
                        if selectedThemeId == option.id {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(currentTheme.accent)
                        } else if isLocked {
                            // Subtle lock icon, but we have the big badge too
                           // Image(systemName: "lock")
                             //   .foregroundStyle(.gray)
                        } else {
                            // Placeholder for alignment
                             Image(systemName: "circle")
                                .font(.title3)
                                .opacity(0)
                        }
                    }
                }
                .padding(.vertical, 8)
                .listRowBackground(
                    isLocked 
                    ? Color.gray.opacity(0.15) // Different background for locked
                    : currentTheme.background.opacity(isDarkThemeRow(option) ? 0.3 : 0.6)
                )
            }
        }
        .navigationTitle("Appearance")
        .scrollContentBackground(.hidden)
        .background(currentTheme.background.ignoresSafeArea())
        .sheet(item: $previewTheme) { theme in
            ThemePreviewSheet(theme: theme)
        }
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
    
    private func checkLockStatus(for theme: Theme) -> (Bool, String) {
        guard let req = theme.unlockRequirement else {
            return (false, "")
        }
        
        switch req {
        case .level(let level):
            let current = LevelManager.shared.currentLevel
            if current >= level {
                return (false, "")
            } else {
                return (true, "Reach Level \(level)")
            }
        case .invites(let needed):
            let current = AuthManager.shared.profile?.invitationsCount ?? 0
            if current >= needed {
                return (false, "")
            } else {
                return (true, "Invite \(needed) Friends (\(current)/\(needed))")
            }
        case .streak(let needed):
            let current = StreakManager.shared.currentStreak
            if current >= needed {
                return (false, "")
            } else {
                return (true, "\(needed)-Day Streak (\(current)/\(needed))")
            }
        case .premium:
             return (true, "Premium Only") // Placeholder
        }
    }

    private func isDarkThemeRow(_ option: Theme) -> Bool {
        // Helper to adjust row contrast if needed
        return currentTheme.isDark
    }
}

// MARK: - Preview Sheet
struct ThemePreviewSheet: View {
    let theme: Theme
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                theme.background.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Spacer()
                    
                    // Mock UI to show theme
                    VStack(spacing: 16) {
                        Text(theme.name)
                            .font(.largeTitle.bold())
                            .foregroundStyle(theme.primary)
                        
                        Text("This is how your app will look.")
                            .foregroundStyle(theme.secondary)
                        
                        Button("Primary Action") {}
                            .buttonStyle(.borderedProminent)
                            .tint(theme.accent)
                        
                        Button("Secondary Action") {}
                            .buttonStyle(.bordered)
                            .tint(theme.accent)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding()
                    
                    Spacer()
                    
                    // Temp Placeholder Image
                    Image(systemName: "photo.on.rectangle")
                         .font(.system(size: 60))
                         .foregroundStyle(.secondary.opacity(0.3))
                         .padding(.bottom, 50)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}
