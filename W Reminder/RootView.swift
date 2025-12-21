//
//  RootView.swift
//  W Reminder
//

import SwiftUI
import SwiftData
import UserNotifications
import AVFoundation
import AudioToolbox
import WidgetKit

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
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
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
    @State private var syncManager = SyncManager.shared // Observe updates

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
        .preferredColorScheme(theme.isDark ? .dark : .light)
        .overlay {
            if StreakManager.shared.showCelebration {
                ConfettiView()
                    .allowsHitTesting(false) // Don't block touches
            }
            
            if syncManager.isSyncing {
                SyncLoadingView()
            }
            
            GamificationOverlay()
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

// MARK: - Sync Loading View
struct SyncLoadingView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                
                Text("Syncing...")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .padding(24)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(radius: 10)
        }
    }
}

// MARK: - Confetti Effect
struct ConfettiView: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            ForEach(0..<50) { _ in
                ConfettiParticle()
            }
        }
        .onAppear {
            animate = true
        }
    }
}

struct ConfettiParticle: View {
    @State private var animationDuration = Double.random(in: 1...2)
    @State private var xOffset = Double.random(in: -100...100)
    @State private var yOffset = Double.random(in: -200...200)
    @State private var rotation = Double.random(in: 0...360)
    @State private var color = [Color.red, .blue, .green, .yellow, .pink, .purple, .orange].randomElement()!
    @State private var opacity = 1.0
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .offset(x: 0, y: 0) // Start at center
            .overlay(
                 Circle().stroke(Color.white, lineWidth: 1)
            )
            .modifier(ParticleModifier(x: xOffset, y: yOffset, duration: animationDuration, rotate: rotation))
    }
}

struct ParticleModifier: ViewModifier {
    let x: Double
    let y: Double
    let duration: Double
    let rotate: Double
    
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .offset(x: isAnimating ? x : 0, y: isAnimating ? y : 0)
            .rotationEffect(.degrees(isAnimating ? rotate : 0))
            .opacity(isAnimating ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: duration)) {
                    isAnimating = true
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
    @AppStorage("isHapticsEnabled") private var isHapticsEnabled = true
        
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
                                    await SyncManager.shared.sync(container: modelContext.container)
                                    // 2. Wipe local data (Clean Slate)
                                    try? SyncManager.shared.deleteLocalData(context: modelContext)
                                    LevelManager.shared.resetLocalData()
                                    StreakManager.shared.resetLocalData()
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
                
                Section("Notifications & Haptics") {
                    HStack {
                        Label("Status", systemImage: "bell.badge.fill")
                        Spacer()
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        Text(statusLabel)
                            .foregroundStyle(.secondary)
                    }
                    
                    Toggle(isOn: $isHapticsEnabled) {
                        Label("Vibration", systemImage: "iphone.radiowaves.left.and.right")
                    }
                    .tint(theme.accent)
                    
                    // Silent Mode Info
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "bell.slash")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Silent Mode")
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                            
                            Text("If your device's Silent Switch is on, notification sounds will be muted and you will only feel vibrations.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                    
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
                .onChange(of: notificationSound) { oldValue, newValue in
                    Task {
                        await authManager.updateSettings(themeId: selectedThemeId, sound: newValue.rawValue)
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
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .onChange(of: selectedThemeId) { oldValue, newValue in
                    Task {
                        await authManager.updateSettings(themeId: newValue, sound: notificationSound.rawValue)
                    }
                    // Sync to Widget
                    if let defaults = UserDefaults(suiteName: SharedPersistence.appGroupIdentifier) {
                        defaults.set(newValue, forKey: "widgetThemeId")
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }
                .onAppear {
                    // Ensure widget has current theme
                    if let defaults = UserDefaults(suiteName: SharedPersistence.appGroupIdentifier) {
                        defaults.set(selectedThemeId, forKey: "widgetThemeId")
                    }
                }

                Section("About") {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text("1.03 beta")
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
        
        // Handle Vibration Preference
        if isHapticsEnabled {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
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
