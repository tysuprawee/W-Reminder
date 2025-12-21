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
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Checklist.self,
            ChecklistItem.self,
            SimpleChecklist.self,
            Tag.self,
            DeletedRecord.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }   
    }()

    init() {
        // Ask for notification permission when the app starts
        NotificationManager.shared.requestAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)

    }
}
