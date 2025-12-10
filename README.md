# W Reminder

A modern, beautifully designed task management and reminder app for iOS, built with SwiftUI and SwiftData.

## Features

### 📋 Dual Task System
- **Milestones**: Complex tasks with multiple checklist items, perfect for projects and multi-step goals
- **Simple Checklists**: Quick, single-step tasks for everyday reminders

### 🏷️ Smart Tagging
- Create unlimited custom tags with personalized colors
- Multi-tag support (up to 3 tags per task)
- Filter tasks by tags across all views
- GitHub-style tag design with automatic text color contrast

### 📅 Smart Scheduling
- Flexible date and time selection with graphical date picker
- Live countdown timers showing time remaining
- Overdue task indicators
- Optional reminder notifications

### 🔔 Notifications
- Local push notifications for scheduled tasks
- Automatic notification management
- Permission handling with user-friendly alerts

### ✨ Modern UI/UX
- Beautiful glassmorphism design with gradient backgrounds
- Smooth animations and transitions
- Dark mode compatible
- Custom toggle switches and color pickers
- Floating Action Button (FAB) for quick task creation

### 📊 Organization
- **Manual ordering**: Drag and drop to reorder tasks
- **Sort options**: Manual order, Earliest Due, Latest Due
- **Calendar View**: Monthly overview with date-based task grouping
- **Records View**: Archive of completed tasks

### ⏱️ Live Updates
- Real-time countdown timers that update every minute
- Automatic progress tracking for milestone tasks
- Dynamic visual feedback

## Technology Stack

- **Framework**: SwiftUI
- **Persistence**: SwiftData
- **Notifications**: UserNotifications framework
- **Platform**: iOS 17.0+
- **Language**: Swift

## Project Structure

```
W Reminder/
├── W_ReminderApp.swift          # App entry point
├── Models/
│   ├── Checklist.swift          # Milestone task model
│   ├── ChecklistItem.swift      # Subtask model (embedded in Checklist)
│   ├── SimpleChecklist.swift    # Simple task model
│   └── Tag.swift                # Tag model
├── Views/
│   ├── ContentView.swift        # Main milestone view (MilestoneView)
│   ├── SimpleChecklistView.swift # Simple checklists view
│   ├── CalendarView.swift       # Monthly calendar view
│   ├── RecordsView.swift        # Completed tasks archive
│   └── AddChecklistView.swift   # Task creation/editing (for both types)
├── Components/
│   ├── CustomToggle.swift       # Custom toggle switch
│   └── CustomColorPicker.swift  # Color selection component
├── Utilities/
│   ├── Theme.swift              # Theme configuration
│   ├── NotificationManager.swift # Notification handling
│   └── Extensions.swift         # Color and other extensions
└── Assets/
    └── Assets.xcassets          # App icons and colors
```

## Key Models

### Checklist (Milestone)
- Multi-item task with progress tracking
- Support for notes, due dates, and tags
- Relationship with ChecklistItem for subtasks
- Manual ordering support

### SimpleChecklist
- Single-step task
- Support for notes, due dates, and tags
- Toggle-based completion

### Tag
- Custom name and color
- Reusable across all tasks
- Visual consistency with contrast-aware text

## Installation

1. Clone the repository
2. Open `W Reminder.xcodeproj` in Xcode 15 or later
3. Select your target device or simulator
4. Build and run (⌘R)

## Usage

### Creating a Milestone
1. Tap the **+** button in the Milestones tab
2. Enter a title and optional notes
3. Add tags for organization
4. Set a deadline with optional reminder
5. Add checklist items for subtasks
6. Tap **Save**

### Creating a Simple Checklist
1. Navigate to the **Checklists** tab
2. Tap the **+** button
3. Enter a title and optional notes
4. Add tags and set a deadline if needed
5. Tap **Save**

### Managing Tasks
- **Edit**: Tap on a task or use the Edit button
- **Delete**: Swipe left on a task
- **Reorder**: Long press and drag (when sorted by Manual Order)
- **Complete**: Tap the checkmark circle (Simple) or check all items (Milestone)
- **Filter**: Use the filter button to show tasks by tag

### Calendar View
- View all tasks organized by date
- See monthly overview
- Tap dates to focus on specific days

### Records
- View completed tasks
- Edit or restore completed tasks
- Clear all records by type

## Features in Detail

### Live Timer Updates
Tasks display live countdowns that update every minute, showing:
- Time remaining until due
- Overdue duration for past tasks
- Human-readable format (minutes, hours, days)

### Drag & Drop Reordering
When sorted by "Manual Order", tasks can be reordered via drag and drop. The custom order persists across app sessions.

### Tag System
- Create unlimited tags with custom colors
- Visual tag chips with automatic text contrast
- Up to 3 tags per task for organization
- Delete unused tags via context menu
- Filter view by individual tags

### Progress Tracking
Milestone tasks show:
- Visual progress bar
- "X/Y done" counter
- Percentage completion

## Notifications

The app uses local notifications to remind you of tasks:
- Permission requested on first use
- Notifications scheduled based on due date/time
- Automatic cleanup when tasks are completed or deleted
- Configurable per-task (can disable reminders)

## Future Enhancements

Ideas documented in `community_strategy.md`:
- Cloud sync and sharing capabilities
- Collaborative checklists
- Template system
- Widgets
- Watch app integration

## License

Private project - All rights reserved

## Author

Created by Suprawee Pongpeeradech

---

**Built with ❤️ using SwiftUI**
