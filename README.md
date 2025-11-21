# W Reminder

W Reminder is a minimal SwiftUI iOS app for time-based reminders that stay fully on your device. It uses SwiftData for persistence and UserNotifications for local alerts while keeping a calm, warm theme so managing tasks feels supportive instead of stressful.

## Features
- Create reminders with a title, date & time, and optional notes.
- Reminders are stored locally with SwiftData and sorted by soonest first.
- Local notifications fire at the reminder time and are cancelled when the reminder is deleted.
- Clean SwiftUI interface that fits the "Warm Focus" theme.

## Project structure
- `W_ReminderApp.swift`: Configures the SwiftData `ModelContainer`, requests notification authorization, and hosts the root `ContentView` scene.
- `Reminder.swift`: SwiftData model representing a single reminder (identifier, title, due date, optional notes).
- `NotificationManager.swift`: Singleton that requests notification permission, schedules reminder notifications, and cancels them on deletion.
- `ContentView.swift`: Main UI that lists reminders, supports deletion, and presents the add-reminder flow.
- `Assets.xcassets` & `Preview Content/`: App assets and SwiftUI previews.

## Requirements
- Xcode 16 or later
- iOS 18.2 simulator (e.g., iPhone 16 Pro) or a physical device for best notification fidelity

## Running the app
1. Open the Xcode project `W Reminder.xcodeproj`.
2. Select an iOS 18.2 simulator (or a physical device) and build & run (`⌘ + R`).
3. On first launch, grant notification permission when prompted.
4. Tap the **+** button to add a reminder, then wait for the scheduled time to receive the local notification.

## Development notes
- Notifications use each reminder's `id` as the notification identifier; deleting a reminder cancels its pending notification.
- SwiftData persists reminders on device using the configured `ModelContainer` in `W_ReminderApp.swift`.
- The design aims to feel warm and calm; stick to soft accents, light backgrounds, and clear typography when extending the UI.
