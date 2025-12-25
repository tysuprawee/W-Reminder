import SwiftUI
import WidgetKit

struct ThemeSelectionView: View {
    @Binding var selectedThemeId: String
    let currentTheme: Theme
    
    @State private var path = NavigationPath() // For navigation

    var body: some View {
        List {
            ForEach(Theme.all) { option in
                let (isLocked, requirementText) = checkLockStatus(for: option)
                
                HStack(spacing: 16) {
                    // 1. Selection Button Area (Leading)
                    Button {
                        if !isLocked {
                            withAnimation {
                                selectedThemeId = option.id
                            }
                        }
                    } label: {
                        HStack(spacing: 16) {
                            themeSwatch(for: option)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text(option.name)
                                    .font(.headline)
                                    .foregroundStyle(currentTheme.primary)
                                    .fixedSize(horizontal: false, vertical: true) // Allow wrapping text
                                
                                if isLocked {
                                    // BADGE MOVED HERE (Vertical Stack)
                                    HStack(spacing: 6) {
                                        Image(systemName: "lock.fill")
                                            .font(.caption2)
                                        Text(requirementText)
                                            .font(.caption.bold())
                                            .lineLimit(1) // Keep single line if possible or wrap gently
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(currentTheme.background)
                                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                                    )
                                    .foregroundStyle(currentTheme.primary)
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
                    
                    // 2. Trailing Actions
                    HStack(spacing: 12) {
                        // PREVIEW BUTTON (Manual Navigation Link)
                        ZStack {
                            NavigationLink(destination: ThemePreviewSheet(theme: option)) {
                                EmptyView()
                            }
                            .opacity(0) // Hide the chevron/link
                            
                            Image(systemName: "eye")
                                .font(.system(size: 18))
                                .foregroundStyle(currentTheme.secondary)
                                .padding(6)
                                .background(currentTheme.secondary.opacity(0.1)) // Only visible background
                                .clipShape(Circle())
                        }
                        .frame(width: 32, height: 32)
                        
                        // STATUS ICON
                        Button {
                            if !isLocked {
                                withAnimation { selectedThemeId = option.id }
                            }
                        } label: {
                            ZStack {
                                if selectedThemeId == option.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(currentTheme.accent)
                                } else if isLocked {
                                    Image(systemName: "lock.fill")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Image(systemName: "circle")
                                        .font(.title3)
                                        .foregroundStyle(.secondary.opacity(0.5))
                                }
                            }
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .disabled(isLocked)
                    }
                }
                .padding(.horizontal, 20) // Manual Padding
                .padding(.vertical, 12)
                .listRowInsets(EdgeInsets()) // Remove default padding
                .listRowSeparator(.hidden)
                .listRowBackground(
                    isLocked 
                    ? Color.gray.opacity(0.15) 
                    : currentTheme.background.opacity(isDarkThemeRow(option) ? 0.3 : 0.6)
                )
            }
        }
        .listStyle(.plain) // Use Plain style to remove grouped insets completely
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
        .navigationTitle(theme.name) // Use Theme Name
        .navigationBarTitleDisplayMode(.inline)
        // Dynamically adjust nav bar text color (White for Dark themes, Black for Light themes)
        .preferredColorScheme(theme.isDark ? .dark : .light)
    }
}
