//
//  W_ReminderApp.swift
//  W Reminder
//
//  Created by Suprawee Pongpeeradech on 11/20/25.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct W_ReminderApp: App {
    // Use the shared persistence controller (App Group aware)
    var sharedModelContainer: ModelContainer = SharedPersistence.shared.container

    init() {
        // Ask for notification permission when the app starts
        NotificationManager.shared.requestAuthorization()
        
        // Restore Streak state on launch
        StreakManager.shared.checkStreak()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)

    }
}
