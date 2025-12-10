//
//  NotificationManager.swift
//  W Reminder
//

import Foundation
import UserNotifications

/// Handles all local notification work for the app, including foreground delivery.
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if let error = error {
                    print("Notification permission error: \(error)")
                } else {
                    print("Notification permission granted: \(granted)")
                }
                DispatchQueue.main.async {
                    completion?(granted)
                }
            }
    }

    func scheduleNotification(for checklist: Checklist) {
        guard checklist.remind, let dueDate = checklist.dueDate, dueDate > Date() else { return }

        let center = UNUserNotificationCenter.current()

        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }

            guard settings.authorizationStatus == .authorized ||
                    settings.authorizationStatus == .provisional else {
                self.requestAuthorization()
                return
            }

            let content = UNMutableNotificationContent()
            content.title = checklist.title

            if let notes = checklist.notes, !notes.isEmpty {
                content.body = notes
            } else {
                content.body = "Checklist due."
            }

            content.sound = self.getNotificationSound()

            let triggerDate = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: dueDate
            )

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: triggerDate,
                repeats: false
            )

            let request = UNNotificationRequest(
                identifier: checklist.id.uuidString,
                content: content,
                trigger: trigger
            )

            center.add(request) { error in
                if let error = error {
                    print("Error scheduling notification: \(error)")
                } else {
                    print("Notification scheduled for \(String(describing: checklist.dueDate))")
                }
            }
        }
    }

    func cancelNotification(for checklist: Checklist) {
        let identifier = checklist.id.uuidString
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    func scheduleNotification(for checklist: SimpleChecklist) {
        guard checklist.remind, let dueDate = checklist.dueDate, dueDate > Date() else { return }

        let center = UNUserNotificationCenter.current()

        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }

            guard settings.authorizationStatus == .authorized ||
                    settings.authorizationStatus == .provisional else {
                self.requestAuthorization()
                return
            }

            let content = UNMutableNotificationContent()
            content.title = checklist.title
            content.body = checklist.notes ?? "Checklist reminder."
            content.sound = self.getNotificationSound()

            let triggerDate = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: dueDate
            )

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: triggerDate,
                repeats: false
            )

            let request = UNNotificationRequest(
                identifier: checklist.id.uuidString,
                content: content,
                trigger: trigger
            )

            center.add(request)
        }
    }

    func cancelNotification(for checklist: SimpleChecklist) {
        let identifier = checklist.id.uuidString
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    // Show notification while app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
    
    // Helper to get notification sound from preferences
    private func getNotificationSound() -> UNNotificationSound {
        if let soundName = UserDefaults.standard.string(forKey: "notificationSound") {
            switch soundName {
            case "Bell": return UNNotificationSound(named: UNNotificationSoundName(rawValue: "bell.caf"))
            case "Chime": return UNNotificationSound(named: UNNotificationSoundName(rawValue: "chime.caf"))
            case "Alert": return UNNotificationSound(named: UNNotificationSoundName(rawValue: "alert.caf"))
            case "Ping": return UNNotificationSound(named: UNNotificationSoundName(rawValue: "ping.caf"))
            default: return .default
            }
        }
        return .default
    }
}
