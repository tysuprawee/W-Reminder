//
//  WReminderWidget.swift
//  W Reminder
//
//  IMPORTANT: Add this file to your WReminderWidget Target
//  IMPORTANT: Ensure SharedPersistence.swift and all Model files (Checklist.swift, etc.) are also in the Widget Target.
//

import WidgetKit
import SwiftUI
import SwiftData

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        let entry = SimpleEntry(date: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        // Refresh every 15 minutes or when app data changes
        let currentDate = Date()
        let entry = SimpleEntry(date: currentDate)
        
        let nextUpdateDate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdateDate))
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}

struct WReminderWidgetEntryView : View {
    var entry: Provider.Entry
    
    // Query items due today or overdue, not done
    @Query(sort: \SimpleChecklist.dueDate, order: .forward) 
    var simpleChecklists: [SimpleChecklist]
    
    @Query(sort: \Checklist.dueDate, order: .forward) 
    var milestones: [Checklist]

    @Environment(\.widgetFamily) var family

    var theme: Theme {
        let defaults = UserDefaults(suiteName: SharedPersistence.appGroupIdentifier)
        let id = defaults?.string(forKey: "widgetThemeId") ?? Theme.default.id
        return Theme.all.first { $0.id == id } ?? .default
    }

    var body: some View {
        Group {
            if family == .systemSmall {
                SmallWidgetView(simples: simpleChecklists, milestones: milestones, theme: theme)
            } else if family == .systemMedium {
                MediumWidgetView(simples: simpleChecklists, milestones: milestones, theme: theme)
            } else {
                LargeWidgetView(simples: simpleChecklists, milestones: milestones, theme: theme)
            }
        }
    }
}

// MARK: - Views

struct SmallWidgetView: View {
    let simples: [SimpleChecklist]
    let milestones: [Checklist]
    let theme: Theme
    
    var progress: Double {
        return 0.75 // Placeholder
    }
    
    var currentStreak: Int {
        let defaults = UserDefaults(suiteName: SharedPersistence.appGroupIdentifier)
        return defaults?.integer(forKey: "userStreakCount") ?? 0
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background Ring
                Circle()
                    .stroke(theme.secondary.opacity(0.3), lineWidth: 8)
                    
                // Gradient Ring (Active)
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(
                        AngularGradient(
                            colors: [theme.accent, theme.primary],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                
                // Streak Count
                VStack(spacing: 0) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                        .foregroundStyle(theme.accent)
                    Text("\(currentStreak)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.primary)
                        .contentTransition(.numericText())
                }
            }
            .padding(4)
            
            Text("Day Streak")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(theme.secondary)
        }
        .containerBackground(for: .widget) {
            theme.background
        }
    }
}

struct MediumWidgetView: View {
    let simples: [SimpleChecklist]
    let milestones: [Checklist]
    let theme: Theme
    
    var combinedTasks: [AnyTask] {
        let s = simples.filter { !$0.isDone }.map { AnyTask(title: $0.title, dueDate: $0.dueDate, isMilestone: false) }
        let m = milestones.filter { !$0.isDone }.map { AnyTask(title: $0.title, dueDate: $0.dueDate, isMilestone: true) }
        
        return (s + m).sorted { a, b in
            guard let da = a.dueDate else { return false }
            guard let db = b.dueDate else { return true }
            return da < db
        }.prefix(3).map { $0 } // Top 3
    }
    
    struct AnyTask: Identifiable {
        let id = UUID()
        let title: String
        let dueDate: Date?
        let isMilestone: Bool
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Upcoming")
                    .font(.headline)
                    .foregroundStyle(theme.primary)
                Spacer()
                Image(systemName: "checklist")
                    .foregroundStyle(theme.accent)
            }
            
            Divider().background(theme.secondary)
            
            if combinedTasks.isEmpty {
                Text("All clear! 🎉")
                    .foregroundStyle(theme.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(combinedTasks) { task in
                    HStack {
                        Image(systemName: task.isMilestone ? "flag.fill" : "circle")
                            .font(.caption2)
                            .foregroundStyle(task.isMilestone ? theme.accent : theme.primary)
                        
                        Text(task.title)
                            .font(.subheadline)
                            .lineLimit(1)
                            .foregroundStyle(theme.primary)
                        
                        Spacer()
                        
                        if let date = task.dueDate {
                            Text(date, format: .dateTime.hour().minute())
                                .font(.caption2)
                                .foregroundStyle(theme.secondary)
                        }
                    }
                }
            }
            Spacer()
        }
        .padding()
        .containerBackground(for: .widget) {
            theme.background
        }
    }
}

struct LargeWidgetView: View {
    let simples: [SimpleChecklist]
    let milestones: [Checklist]
    let theme: Theme
    
    var combinedTasks: [MediumWidgetView.AnyTask] {
        let s = simples.filter { !$0.isDone }.map { MediumWidgetView.AnyTask(title: $0.title, dueDate: $0.dueDate, isMilestone: false) }
        let m = milestones.filter { !$0.isDone }.map { MediumWidgetView.AnyTask(title: $0.title, dueDate: $0.dueDate, isMilestone: true) }
        
        // Show Top 8 for Large
        return (s + m).sorted { a, b in
            guard let da = a.dueDate else { return false }
            guard let db = b.dueDate else { return true }
            return da < db
        }.prefix(8).map { $0 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
             HStack {
                Text("Upcoming Tasks")
                    .font(.title3.bold())
                    .foregroundStyle(theme.primary)
                Spacer()
                Image(systemName: "calendar")
                    .foregroundStyle(theme.accent)
            }
            
            Divider().background(theme.secondary)
            
            if combinedTasks.isEmpty {
                 VStack {
                    Spacer()
                    Text("All caught up! 🚀")
                        .font(.headline)
                        .foregroundStyle(theme.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 8) {
                    ForEach(combinedTasks) { task in
                        HStack {
                            Image(systemName: task.isMilestone ? "flag.fill" : "circle")
                                .font(.caption2)
                                .foregroundStyle(task.isMilestone ? theme.accent : theme.primary)
                            
                            Text(task.title)
                                .font(.subheadline)
                                .lineLimit(1)
                                .foregroundStyle(theme.primary)
                            
                            Spacer()
                            
                            if let date = task.dueDate {
                                Text(date, format: .dateTime.weekday().hour().minute())
                                    .font(.caption2)
                                    .foregroundStyle(theme.secondary)
                            }
                        }
                        Divider().opacity(0.3)
                    }
                }
            }
            Spacer()
        }
        .padding()
        .containerBackground(for: .widget) {
            theme.background
        }
    }
}

@main
struct WReminderWidget: Widget {
    let kind: String = "WReminderWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WReminderWidgetEntryView(entry: entry)
                .modelContainer(SharedPersistence.shared.container)
        }
        .configurationDisplayName("W Reminder")
        .description("Track your tasks and milestones.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
