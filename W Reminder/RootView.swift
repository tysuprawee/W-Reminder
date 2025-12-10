//
//  RootView.swift
//  W Reminder
//

import SwiftUI
import SwiftData
import UserNotifications
import AVFoundation

struct RootView: View {
    @AppStorage("selectedThemeId") private var selectedThemeId: String = Theme.default.id

    private var selectedTheme: Theme {
        Theme.all.first(where: { $0.id == selectedThemeId }) ?? .default
    }

    var body: some View {
        TabView {
            MilestoneView(theme: selectedTheme)
                .tabItem {
                    Label("Milestones", systemImage: "flag.checkered")
                }

            SimpleChecklistView(theme: selectedTheme)
                .tabItem {
                    Label("Checklists", systemImage: "checklist")
                }

            CalendarView(theme: selectedTheme)
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }

            RecordsView(theme: selectedTheme)
                .tabItem {
                    Label("Records", systemImage: "tray.full")
                }

            SettingsView(selectedThemeId: $selectedThemeId, theme: selectedTheme)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(selectedTheme.accent)
    }
}

struct SettingsView: View {
    @Binding var selectedThemeId: String
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @AppStorage("notificationSound") private var notificationSound = NotificationSound.default

    let theme: Theme

    var body: some View {
        NavigationStack {
            List {
                Section("Notifications") {
                    HStack {
                        Label("Status", systemImage: "bell.badge")
                        Spacer()
                        Text(statusLabel)
                            .foregroundStyle(statusColor)
                            .font(.subheadline.bold())
                    }

                    Button("Allow Notifications") {
                        NotificationManager.shared.requestAuthorization()
                        refreshNotificationStatus()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.accent)

                    if notificationStatus == .denied {
                        Button("Open Settings") {
                            openAppSettings()
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
            .onAppear {
                refreshNotificationStatus()
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
        // Play system sound based on selected notification sound
        let soundID: SystemSoundID
        
        switch notificationSound {
        case .default:
            soundID = 1007 // SMS Received 1
        case .bell:
            soundID = 1013 // SMS Received 5
        case .chime:
            soundID = 1016 // SMS Received 6
        case .alert:
            soundID = 1005 // New Mail
        case .ping:
            soundID = 1003 // SMS Received 3
        }
        
        AudioServicesPlaySystemSound(soundID)
    }
    
    private func refreshNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationStatus = settings.authorizationStatus
            }
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
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
    case bell = "Bell"
    case chime = "Chime"
    case alert = "Alert"
    case ping = "Ping"
    
    var id: String { self.rawValue }
    
    var fileName: String? {
        switch self {
        case .default: return nil
        case .bell: return "bell.caf"
        case .chime: return "chime.caf"
        case .alert: return "alert.caf"
        case .ping: return "ping.caf"
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: [Checklist.self, ChecklistItem.self, SimpleChecklist.self, Tag.self], inMemory: true)
}

