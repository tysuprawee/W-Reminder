//
//  NotificationManager.swift
//  W Reminder
//

import Foundation
import UserNotifications
import SwiftData

/// Handles all local notification work for the app, including foreground delivery.
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    // Define Categories and Actions
    private let categoryID = "CHECKLIST_REMINDER"
    private let actionComplete = "ACTION_COMPLETE"
    private let actionSnooze = "ACTION_SNOOZE"

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        registerCategories()
    }
    
    private func registerCategories() {
        let completeAction = UNNotificationAction(
            identifier: actionComplete,
            title: "Mark as Done",
            options: .authenticationRequired
        )
        let snoozeAction = UNNotificationAction(
            identifier: actionSnooze,
            title: "Snooze 1h",
            options: [] // No auth needed for snooze
        )
        
        let category = UNNotificationCategory(
            identifier: categoryID,
            actions: [completeAction, snoozeAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
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
        guard !checklist.isDone, checklist.remind, let dueDate = checklist.dueDate, dueDate > Date() else { return }
        
        schedule(
            id: checklist.id,
            title: checklist.title,
            body: checklist.notes ?? "Checklist due.",
            date: dueDate,
            userInfo: [
                "type": "milestone",
                "id": checklist.id.uuidString
            ]
        )
    }

    func cancelNotification(for checklist: Checklist) {
        let identifier = checklist.id.uuidString
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    func scheduleNotification(for checklist: SimpleChecklist) {
        guard !checklist.isDone, checklist.remind, let dueDate = checklist.dueDate, dueDate > Date() else { return }

        schedule(
            id: checklist.id,
            title: checklist.title,
            body: checklist.notes ?? "Checklist reminder.",
            date: dueDate,
            userInfo: [
                "type": "simple",
                "id": checklist.id.uuidString
            ]
        )
    }

    func cancelNotification(for checklist: SimpleChecklist) {
        let identifier = checklist.id.uuidString
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    private func schedule(id: UUID, title: String, body: String, date: Date, userInfo: [AnyHashable: Any]) {
        let center = UNUserNotificationCenter.current()
        
        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }
            
            guard settings.authorizationStatus == .authorized ||
                    settings.authorizationStatus == .provisional else {
                self.requestAuthorization()
                return
            }
            
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = self.getNotificationSound()
            content.categoryIdentifier = self.categoryID
            content.userInfo = userInfo
            
            let triggerDate = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: date
            )
            
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: triggerDate,
                repeats: false
            )
            
            let request = UNNotificationRequest(
                identifier: id.uuidString,
                content: content,
                trigger: trigger
            )
            
            center.add(request) { error in
                if let error = error {
                    print("Error scheduling notification: \(error)")
                } else {
                    print("Notification scheduled for \(date)")
                }
            }
        }
    }

    // Show notification while app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle Interactive Actions
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        guard let idString = userInfo["id"] as? String,
              let id = UUID(uuidString: idString),
              let type = userInfo["type"] as? String else {
            completionHandler()
            return
        }
        
        switch response.actionIdentifier {
        case actionComplete:
            Task {
                await handleCompletion(id: id, type: type)
            }
        case actionSnooze:
            handleSnooze(response: response)
        default:
            break
        }
        
        completionHandler()
    }
    
    @MainActor
    private func handleCompletion(id: UUID, type: String) {
        // Use the SharedPersistence container to ensure we access the correct App Group database
        let container = SharedPersistence.shared.container
        let context = container.mainContext // Use mainContext as this is MainActor
        
        Task {
            do {
                print("Notification: Processing completion for \(type)...")
                
                if type == "simple" {
                    var descriptor = FetchDescriptor<SimpleChecklist>(predicate: #Predicate { $0.id == id })
                    descriptor.fetchLimit = 1
                    if let item = try context.fetch(descriptor).first {
                        item.isDone = true
                        item.completedAt = Date()
                        
                        // Handle Recurrence
                        if let rule = item.recurrenceRule, let currentDue = item.dueDate {
                            if let nextDate = RecurrenceHelper.calculateNextDueDate(from: currentDue, rule: rule) {
                                let newItem = SimpleChecklist(
                                    title: item.title,
                                    notes: item.notes,
                                    dueDate: nextDate,
                                    remind: item.remind,
                                    isDone: false,
                                    tags: item.tags,
                                    isStarred: item.isStarred,
                                    userOrder: item.userOrder,
                                    recurrenceRule: rule
                                )
                                context.insert(newItem)
                            }
                        }
                        try context.save()
                        print("Notification: Simple Checklist \(item.title) marked done.")
                        
                        StreakManager.shared.incrementStreak()
                        await SyncManager.shared.sync(container: container)
                    }
                } else if type == "milestone" {
                    var descriptor = FetchDescriptor<Checklist>(predicate: #Predicate { $0.id == id })
                    descriptor.fetchLimit = 1
                    if let item = try context.fetch(descriptor).first {
                        item.isDone = true
                        item.completedAt = Date()
                        
                        // Recurrence explicitly disabled for Milestones per user design.
                        
                        try context.save()
                        print("Notification: Milestone \(item.title) marked done.")
                        
                        StreakManager.shared.incrementStreak()
                        await SyncManager.shared.sync(container: container)
                    }
                }
            } catch {
                print("Notification Action Error: \(error)")
            }
        }
    }
    
    private func handleSnooze(response: UNNotificationResponse) {
        let content = response.notification.request.content
        let newTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false) // 1 Hour
        
        let request = UNNotificationRequest(
            identifier: response.notification.request.identifier,
            content: content,
            trigger: newTrigger
        )
        
        UNUserNotificationCenter.current().add(request)
        print("Notification snoozed for 1 hour.")
    }
    
    // Helper to get notification sound from preferences
    private func getNotificationSound() -> UNNotificationSound {
        if let soundName = UserDefaults.standard.string(forKey: "notificationSound") {
            switch soundName {
            case "Bells Echo": return UNNotificationSound(named: UNNotificationSoundName(rawValue: "bells-echo.wav"))
            case "Game": return UNNotificationSound(named: UNNotificationSoundName(rawValue: "game.wav"))
            default: return .default
            }
        }
        return .default
    }
}
