//
//  RootView.swift
//  W Reminder
//

import SwiftUI
import SwiftData
import UserNotifications
import AVFoundation

// Simple Audio Player for Previews
class SoundPlayer: NSObject {
    static let shared = SoundPlayer()
    var audioPlayer: AVAudioPlayer?

    func playSound(named fileName: String) {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: nil) else {
            print("Sound file not found: \(fileName)")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            print("Could not play sound file: \(error)")
        }
    }
}

struct RootView: View {
    @AppStorage("selectedThemeId") private var selectedThemeId: String = Theme.default.id
    @AppStorage("notificationSound") private var notificationSound: NotificationSound = .default

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @Environment(\.scenePhase) private var scenePhase

    var theme: Theme {
        Theme.all.first { $0.id == selectedThemeId } ?? .default
    }

    @AppStorage("hasSeenWelcome") private var hasSeenWelcome: Bool = false
    
    @State private var authInitialized = false
    private let authManager = AuthManager.shared

    var body: some View {
        Group {
            if !hasSeenWelcome {
                WelcomeView {
                    withAnimation {
                        hasSeenWelcome = true
                    }
                }
            } else {
                authenticatedView // This is now the main view for everyone (Guest or Auth)
            }
        }
        .task {
            await authManager.initialize()
            withAnimation {
                authInitialized = true
            }
        }
        .onOpenURL { url in
            // Handle OAuth redirect
            print("Received URL: \(url)")
            authManager.handleIncomingURL(url)
        }
        // Listen for session changes (Just for state updates, not navigation blocking)
        .onChange(of: authManager.session) {old, new in
             if new != nil {
                 print("Session updated: User is authenticated")
             }
        }
    }

    // Rename for clarity, though "authenticatedView" contains the Tabs
    var authenticatedView: some View {
        TabView {
            MilestoneView(theme: theme)
                .tabItem {
                    Label("Milestones", systemImage: "flag.checkered")
                }

            SimpleChecklistView(theme: theme)
                .tabItem {
                    Label("Checklists", systemImage: "checklist")
                }

            CalendarView(theme: theme)
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }

            RecordsView(theme: theme)
                .tabItem {
                    Label("Records", systemImage: "tray.full")
                }

            SettingsView(selectedThemeId: $selectedThemeId, notificationStatus: $notificationStatus, notificationSound: $notificationSound, theme: theme)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(theme.accent)
        .onAppear {
            refreshNotificationStatus()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                refreshNotificationStatus()
            }
        }
    }
    
    private func refreshNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationStatus = settings.authorizationStatus
            }
        }
    }
}

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext // Add this
    @Binding var selectedThemeId: String
    @Binding var notificationStatus: UNAuthorizationStatus
    @Binding var notificationSound: NotificationSound

    let theme: Theme
    
    @Query private var tags: [Tag]
    
    private var tagCount: Int {
        tags.count
    }

    @State private var authManager = AuthManager.shared
    @State private var showLoginSheet = false

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    if authManager.isAuthenticated {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(authManager.user?.email ?? "User")
                                    .font(.headline)
                                Text("Cloud Sync Active")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                            Spacer()
                            Button("Sign Out", role: .destructive) {
                                Task {
                                    // 1. Sync one last time (Backup)
                                    await SyncManager.shared.sync(context: modelContext)
                                    // 2. Wipe local data (Clean Slate)
                                    try? SyncManager.shared.deleteLocalData(context: modelContext)
                                    // 3. Sign Out
                                    await authManager.signOut()
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    } else {
                        Button {
                            showLoginSheet = true
                        } label: {
                            Label("Sign In / Sign Up", systemImage: "person.crop.circle.badge.plus")
                        }
                        .foregroundStyle(theme.accent)
                    }
                }
                
                Section("Notifications") {
                    HStack {
                        Label("Status", systemImage: "bell.badge.fill")
                        Spacer()
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        Text(statusLabel)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Silent Mode Reminder
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundStyle(theme.accent)
                            .font(.title3)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sound Mode")
                                .font(.subheadline.bold())
                            Text("Check your device's silent switch for sound or vibration only")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    if notificationStatus != .authorized {
                        Button {
                            requestNotificationPermission()
                        } label: {
                            Text(notificationStatus == .denied ? "Open Settings" : "Allow Notifications")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Section("Notification Sound") {
                    HStack {
                        Picker("Sound", selection: $notificationSound) {
                            ForEach(NotificationSound.allCases) { sound in
                                Text(sound.rawValue).tag(sound)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        Spacer()
                        
                        Button {
                            playPreviewSound()
                        } label: {
                            Label("Preview", systemImage: "play.circle.fill")
                                .font(.subheadline)
                        }
                        .buttonStyle(.bordered)
                        .tint(theme.accent)
                    }
                }

                Section("Manage Tags") {
                    NavigationLink {
                        TagManagementView(theme: theme)
                    } label: {
                        HStack {
                            Label("Tags", systemImage: "tag.fill")
                            Spacer()
                            Text("\(tagCount) tags")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }
                    }
                }

                Section("Theme") {
                    ForEach(Theme.all) { option in
                        Button {
                            selectedThemeId = option.id
                        } label: {
                            HStack(spacing: 12) {
                                themeSwatch(for: option)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(option.name)
                                        .foregroundStyle(.primary)
                                    Text(option.id == Theme.default.id ? "Default" : "Custom")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selectedThemeId == option.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(option.accent)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("About") {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text("1.01 beta")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showLoginSheet) {
                LoginView()
            }
        }
    }

    private var statusLabel: String {
        switch notificationStatus {
        case .authorized, .provisional:
            return "Allowed"
        case .denied:
            return "Denied"
        case .notDetermined:
            fallthrough
        default:
            return "Not set"
        }
    }

    private var statusColor: Color {
        switch notificationStatus {
        case .authorized, .provisional:
            return .green
        case .denied:
            return .red
        default:
            return .secondary
        }
    }
    
    private func playPreviewSound() {
        // Play the actual sound file using a simple helper
        if let fileName = notificationSound.fileName {
            // Needed to play custom sound file for preview
            SoundPlayer.shared.playSound(named: fileName)
        } else {
            // Default System Sound
            AudioServicesPlaySystemSound(1007)
        }
    }
    
    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .notDetermined:
                    // First time - request permission
                    NotificationManager.shared.requestAuthorization { granted in
                        // Refresh status regardless of result
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            UNUserNotificationCenter.current().getNotificationSettings { newSettings in
                                DispatchQueue.main.async {
                                    self.notificationStatus = newSettings.authorizationStatus
                                }
                            }
                        }
                    }
                case .denied:
                    // Permission denied - open Settings
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                case .authorized, .provisional, .ephemeral:
                    // Already authorized - no action needed
                    break
                @unknown default:
                    break
                }
            }
        }
    }

    private func themeSwatch(for theme: Theme) -> some View {
        HStack(spacing: 6) {
            Circle().fill(theme.primary).frame(width: 16, height: 16)
            Circle().fill(theme.secondary).frame(width: 16, height: 16)
            Circle().fill(theme.accent).frame(width: 16, height: 16)
            Circle().fill(theme.background).frame(width: 16, height: 16)
        }
    }
}

enum NotificationSound: String, CaseIterable, Identifiable {
    case `default` = "Default"
    case bellsEcho = "Bells Echo"
    case game = "Game"
    
    var id: String { self.rawValue }
    
    var fileName: String? {
        switch self {
        case .default: return nil
        case .bellsEcho: return "bells-echo.wav"
        case .game: return "game.wav"
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: [Checklist.self, ChecklistItem.self, SimpleChecklist.self, Tag.self], inMemory: true)
}
