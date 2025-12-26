import SwiftUI
import WidgetKit

struct ThemeSelectionView: View {
    @Binding var selectedThemeId: String
    let currentTheme: Theme
    
    @State private var path = NavigationPath() // For navigation
    @State private var showInvitePromo = false // Promo for Lavender Haze
    @State private var showLoginSheet = false // Guest Check

    var body: some View {
        List {
            ForEach(Theme.all) { option in
                let (isLocked, requirementText) = checkLockStatus(for: option)
                
                HStack(spacing: 16) {
                    // 1. Selection Button Area (Leading)
                    Button {
                        if !isLocked {
                            if !AuthManager.shared.isAuthenticated {
                                showLoginSheet = true
                            } else {
                                withAnimation {
                                    selectedThemeId = option.id
                                }
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
                                if !AuthManager.shared.isAuthenticated {
                                    showLoginSheet = true
                                } else {
                                    withAnimation { selectedThemeId = option.id }
                                }
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
            
            // Padding for Tab Bar
            Color.clear
                .frame(height: 80)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain) // Use Plain style to remove grouped insets completely
        .navigationTitle("Appearance")
        .scrollContentBackground(.hidden)
        .background(currentTheme.background.ignoresSafeArea())
        .onAppear {
             // Check Lavender Haze Promo
             if let lavender = Theme.all.first(where: { $0.id == "lavenderHaze" }) {
                 let (isLocked, _) = checkLockStatus(for: lavender)
                 if isLocked {
                      // Slight delay for better UX
                      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                          showInvitePromo = true
                      }
                 }
             }
        }
        .sheet(isPresented: $showInvitePromo) {
            ThemePromoSheet(theme: Theme.lavenderHaze, currentTheme: currentTheme)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showLoginSheet) {
            LoginView()
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

// MARK: - Promo Sheet
struct ThemePromoSheet: View {
    let theme: Theme // The Locked Theme
    let currentTheme: Theme // For styling context (or use the Locked Theme's style?)
    @Environment(\.dismiss) private var dismiss
    @State private var hasCopied = false
    @State private var showLoginSheet = false // For local handling if needed
    
    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()
            
            if !AuthManager.shared.isAuthenticated {
                // GUEST STATE
                VStack(spacing: 24) {
                    Spacer()
                    
                    Image(systemName: "lock.circle.fill")
                        .font(.system(size: 70))
                        .foregroundStyle(theme.secondary)
                    
                    Text("Unlock More Themes")
                        .font(.title2.bold())
                        .foregroundStyle(theme.primary)
                    
                    Text("Sign in to unlock exclusive themes like \(theme.name), track your streaks, and more!")
                        .font(.body)
                        .foregroundStyle(theme.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button {
                        // We need to trigger the parent to show login, OR show it here.
                        // Since this is a sheet, presenting another sheet on top is fine.
                        showLoginSheet = true
                    } label: {
                        Text("Sign In Now")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(theme.accent)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    Button("Close") { dismiss() }
                        .foregroundStyle(theme.secondary)
                    
                    Spacer()
                }
                .sheet(isPresented: $showLoginSheet) {
                    LoginView()
                }
                
            } else {
                // AUTHENTICATED STATE
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 50))
                            .foregroundStyle(theme.accent)
                            .symbolEffect(.bounce.up, options: .repeating)
                        
                        Text("Unlock \(theme.name)")
                            .font(.title2.bold())
                            .foregroundStyle(theme.primary)
                        
                        Text("Invite 1 friend to unlock this exclusive theme!")
                            .font(.subheadline)
                            .foregroundStyle(theme.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 32)
                    
                    // Instructions Box
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How to Unlock:")
                            .font(.headline)
                            .foregroundStyle(theme.primary)
                        
                        InstructionRow(number: "1", text: "Ask a friend to download W Reminder.", theme: theme)
                        InstructionRow(number: "2", text: "They go to Settings > Enter Code.", theme: theme)
                        InstructionRow(number: "3", text: "They enter your code below.", theme: theme)
                    }
                    .padding()
                    .background(Color.white.opacity(theme.isDark ? 0.05 : 0.4))
                    .cornerRadius(16)
                    .padding(.horizontal)

                    // Invite Code Box
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Invite Code")
                            .font(.caption.bold())
                            .foregroundStyle(theme.secondary)
                            .textCase(.uppercase)
                        
                        HStack {
                            Text(AuthManager.shared.profile?.inviteCode ?? "LOADING")
                                .font(.title3.monospaced().bold())
                                .foregroundStyle(theme.primary)
                            
                            Spacer()
                            
                            Button {
                                if let code = AuthManager.shared.profile?.inviteCode {
                                    UIPasteboard.general.string = code
                                    let generator = UINotificationFeedbackGenerator()
                                    generator.notificationOccurred(.success)
                                    withAnimation { hasCopied = true }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        withAnimation { hasCopied = false }
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: hasCopied ? "checkmark" : "doc.on.doc")
                                    Text(hasCopied ? "Copied" : "Copy")
                                }
                                .font(.callout.bold())
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(theme.accent)
                                .foregroundStyle(theme.isDark ? .black : .white)
                                .clipShape(Capsule())
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(theme.isDark ? 0.1 : 0.5))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    Button("Maybe Later") {
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundStyle(theme.secondary)
                    .padding(.bottom, 20)
                }
            }
        }
        .presentationDetents([.medium, .large]) // Allow expansion
    }
}

struct InstructionRow: View {
    let number: String
    let text: String
    let theme: Theme
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(theme.accent.opacity(0.2))
                .frame(width: 24, height: 24)
                .overlay(
                    Text(number)
                        .font(.caption.bold())
                        .foregroundStyle(theme.accent)
                )
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(theme.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
