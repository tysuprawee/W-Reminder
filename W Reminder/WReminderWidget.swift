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

    var body: some View {
        Group {
            if family == .systemSmall {
                SmallWidgetView(simples: simpleChecklists, milestones: milestones)
            } else {
                MediumWidgetView(simples: simpleChecklists, milestones: milestones)
            }
        }
        .background(Color.black.opacity(0.8)) // Dark background fallback
    }
}

// MARK: - Views

struct SmallWidgetView: View {
    let simples: [SimpleChecklist]
    let milestones: [Checklist]
    
    var progress: Double {
        // Just an example calculation: % of today's tasks done is hard to fetch via Query without predicate for "isDone".
        // Widgets usually show "Remaining".
        // Let's show "Count Remaining".
        return 0.75 // Placeholder visual
    }
    
    var completedToday: Int {
        // Logic requires fetching completed items, but Query excludes them usually if we filter.
        // For now, let's just show Total Pending Count.
        let sCount = simples.filter { !$0.isDone }.count
        let mCount = milestones.filter { !$0.isDone }.count
        return sCount + mCount
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
                    .stroke(Color.white.opacity(0.1), lineWidth: 8)
                    
                // Gradient Ring (Active)
                Circle()
                    .trim(from: 0, to: 0.75) // Static for now, represents "Daily Goal"
                    .stroke(
                        AngularGradient(
                            colors: [.orange, .red],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                
                // Streak Count
                VStack(spacing: 0) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Text("\(currentStreak)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                }
            }
            .padding(4)
            
            Text("Day Streak")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.gray)
        }
        .containerBackground(for: .widget) {
            Color(red: 0.1, green: 0.1, blue: 0.12)
        }
    }
}

struct MediumWidgetView: View {
    let simples: [SimpleChecklist]
    let milestones: [Checklist]
    
    var combinedTasks: [AnyTask] {
        let s = simples.filter { !$0.isDone }.map { AnyTask(title: $0.title, dueDate: $0.dueDate, isMilestone: false) }
        let m = milestones.filter { !$0.isDone }.map { AnyTask(title: $0.title, dueDate: $0.dueDate, isMilestone: true) }
        
        return (s + m).sorted { a, b in
            guard let da = a.dueDate else { return false }
            guard let db = b.dueDate else { return true }
            return da < db
        }.prefix(3).map { $0 }
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
                Text("Today's Tasks")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "checklist")
                    .foregroundStyle(.orange)
            }
            
            Divider().background(Color.gray)
            
            if combinedTasks.isEmpty {
                Text("All clear! 🎉")
                    .foregroundStyle(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(combinedTasks) { task in
                    HStack {
                        Image(systemName: task.isMilestone ? "flag.fill" : "circle")
                            .font(.caption2)
                            .foregroundStyle(task.isMilestone ? .yellow : .blue)
                        
                        Text(task.title)
                            .font(.subheadline)
                            .lineLimit(1)
                            .foregroundStyle(.white)
                        
                        Spacer()
                        
                        if let date = task.dueDate {
                            Text(date, format: .dateTime.hour().minute())
                                .font(.caption2)
                                .foregroundStyle(.gray)
                        }
                    }
                }
            }
            Spacer()
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(red: 0.08, green: 0.08, blue: 0.1)
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
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
