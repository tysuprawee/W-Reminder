//
//  RootView.swift
//  W Reminder
//

import SwiftUI
import UserNotifications
import UIKit

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

#Preview {
    RootView()
        .modelContainer(for: [Checklist.self, ChecklistItem.self, SimpleChecklist.self, Tag.self], inMemory: true)
}

