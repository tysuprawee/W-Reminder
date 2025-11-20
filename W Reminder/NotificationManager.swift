//
//  NotificationManager.swift
//  W Reminder
//

import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    func requestAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if let error = error {
                    print("Notification permission error: \(error)")
                } else {
                    print("Notification permission granted: \(granted)")
                }
            }
    }

    func scheduleNotification(for reminder: Reminder) {
        // Don’t schedule for past dates
        guard reminder.dueDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = reminder.title

        if let notes = reminder.notes, !notes.isEmpty {
            content.body = notes
        } else {
            content.body = "You have a reminder due."
        }

        content.sound = .default

        let triggerDate = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminder.dueDate
        )

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: triggerDate,
            repeats: false
        )

        // ✅ Use our own UUID-based identifier
        let request = UNNotificationRequest(
            identifier: reminder.id.uuidString,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            } else {
                print("Notification scheduled for \(reminder.dueDate)")
            }
        }
    }

    func cancelNotification(for reminder: Reminder) {
        let identifier = reminder.id.uuidString   // ✅ Same identifier
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
