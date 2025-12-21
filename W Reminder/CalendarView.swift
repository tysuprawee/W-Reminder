//
//  CalendarView.swift
//  W Reminder
//
//  Created by Suprawee Pongpeeradech on 11/20/25.
//

import SwiftUI
import SwiftData
import UserNotifications

struct CalendarView: View {
    let theme: Theme

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Checklist.dueDate, order: .forward) private var milestones: [Checklist]
    @Query(sort: \SimpleChecklist.dueDate, order: .forward) private var checklists: [SimpleChecklist]

    @State private var monthOffset = 0 // current month offset
    @State private var selectedDate: Date = Date()
    @State private var editingMilestone: Checklist?
    @State private var editingSimple: SimpleChecklist?
    @AppStorage("isHapticsEnabled") private var isHapticsEnabled = true

    private var calendar: Calendar { Calendar.current }
    
    private var daysInMonth: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: calendarDate) else { return [] }
        
        let daysRange = calendar.range(of: .day, in: .month, for: calendarDate)!
        let firstDay = monthInterval.start
        
        return daysRange.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: firstDay)
        }
    }
    
    private var calendarDate: Date {
        calendar.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date()
    }
    
    private var weekDays: [String] {
        calendar.shortWeekdaySymbols
    }

    @Namespace private var animation

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        theme.background,
                        theme.accent.opacity(0.15),
                        theme.background
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Custom Calendar Grid
                    VStack(spacing: 20) {
                        headerView
                        daysHeaderView
                        calendarGridView
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
                    )
                    .padding()

                    Divider()

                    taskListView
                }
            }
            .navigationTitle("Calendar")
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Text(calendarDate, format: .dateTime.month(.wide).year())
                .font(.title2.bold())
                .foregroundStyle(theme.primary) // Adding explicit theme color
                .shadow(color: theme.primary.opacity(0.1), radius: 2, x: 0, y: 1)
            
            Spacer()
            
            HStack(spacing: 12) {
                Button {
                    withAnimation(.snappy(duration: 0.3)) {
                        monthOffset -= 1
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.bold())
                        .foregroundStyle(theme.primary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)
                        )
                }
                
                Button {
                    withAnimation(.snappy(duration: 0.3)) {
                        monthOffset = 0
                        selectedDate = Date()
                    }
                } label: {
                    Text("Today")
                        .font(.caption.bold())
                        .foregroundStyle(theme.primary)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)
                        )
                }

                Button {
                    withAnimation(.snappy(duration: 0.3)) {
                        monthOffset += 1
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.bold())
                        .foregroundStyle(theme.primary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)
                        )
                }
            }
        }
        .padding(.horizontal, 8)
    }

    private var daysHeaderView: some View {
        HStack {
            ForEach(weekDays, id: \.self) { day in
                Text(day)
                    .font(.caption.bold())
                    .foregroundStyle(theme.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var calendarGridView: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
            // Blank spaces for start of month
            if let first = daysInMonth.first {
                let weekday = calendar.component(.weekday, from: first)
                ForEach(0..<(weekday - 1), id: \.self) { _ in
                    Color.clear
                }
            }
            
            ForEach(daysInMonth, id: \.self) { date in
                DayCell(
                    date: date,
                    isSelected: isSameDay(date, as: selectedDate),
                    isToday: isSameDay(date, as: Date()),
                    theme: theme,
                    milestones: milestones,
                    checklists: checklists,
                    animation: animation
                ) {
                    withAnimation(.snappy) {
                        selectedDate = date
                    }
                }
            }
        }
        .transition(.move(edge: monthOffset > 0 ? .trailing : .leading).combined(with: .opacity))
        .id(monthOffset) // Triggers transition when month changes
    }

    private var taskListView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Tasks for \(selectedDate, format: .dateTime.day().month().year())")
                    .font(.headline)
                    .foregroundStyle(theme.secondary)
                    .padding(.horizontal)
                    .padding(.top)

                let dailyMilestones = milestones.filter { isSameDay($0.dueDate, as: selectedDate) }
                let dailyChecklists = checklists.filter { isSameDay($0.dueDate, as: selectedDate) }

                if dailyMilestones.isEmpty && dailyChecklists.isEmpty {
                    ContentUnavailableView(
                        "No tasks",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("Enjoy your free time!")
                    )
                    .padding(.top, 40)
                } else {
                    if !dailyMilestones.isEmpty {
                        Text("Milestones")
                            .font(.subheadline.bold())
                            .foregroundStyle(theme.accent)
                            .padding(.horizontal)
                        
                        ForEach(dailyMilestones) { milestone in
                            ChecklistRow(
                                checklist: milestone,
                                theme: theme,
                                onEdit: {
                                    editingMilestone = milestone
                                }
                            )
                            .padding(.horizontal)
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    withAnimation {
                                        milestone.isStarred.toggle()
                                    }
                                } label: {
                                    Label(milestone.isStarred ? "Unstar" : "Star", systemImage: milestone.isStarred ? "star.slash" : "star.fill")
                                }
                                .tint(theme.accent)
                            }
                        }
                    }

                    if !dailyChecklists.isEmpty {
                        Text("Checklists")
                            .font(.subheadline.bold())
                            .foregroundStyle(theme.accent)
                            .padding(.horizontal)
                        
                        ForEach(dailyChecklists) { checklist in
                            SimpleChecklistRow(
                                checklist: checklist,
                                theme: theme,
                                onToggleDone: {
                                    withAnimation(.easeInOut) {
                                        checklist.isDone.toggle()
                                    }
                                    
                                    // Haptic Feedback
                                    if isHapticsEnabled && checklist.isDone {
                                        let generator = UIImpactFeedbackGenerator(style: .medium)
                                        generator.impactOccurred()
                                    }
                                    
                                    NotificationManager.shared.cancelNotification(for: checklist)
                                    if checklist.isDone {
                                        StreakManager.shared.incrementStreak()
                                        
                                        // Handle Recurrence
                                        if let rule = checklist.recurrenceRule, let currentDue = checklist.dueDate {
                                            if let nextDate = RecurrenceHelper.calculateNextDueDate(from: currentDue, rule: rule) {
                                                let newItem = SimpleChecklist(
                                                    title: checklist.title,
                                                    notes: checklist.notes,
                                                    dueDate: nextDate,
                                                    remind: checklist.remind,
                                                    isDone: false,
                                                    tags: checklist.tags,
                                                    isStarred: checklist.isStarred,
                                                    userOrder: checklist.userOrder,
                                                    recurrenceRule: rule
                                                )
                                                modelContext.insert(newItem)
                                            }
                                        }
                                    }
                                },
                                onEdit: {
                                    editingSimple = checklist
                                }
                            )
                            .padding(.horizontal)
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    withAnimation {
                                        checklist.isStarred.toggle()
                                    }
                                } label: {
                                    Label(checklist.isStarred ? "Unstar" : "Star", systemImage: checklist.isStarred ? "star.slash" : "star.fill")
                                }
                                .tint(theme.accent)
                            }
                        }
                    }
                }
            }
        }
        .sheet(item: $editingMilestone) { checklist in
            AddChecklistView(
                checklist: checklist,
                theme: theme
            ) { title, notes, dueDate, remind, items, isDone, tags, recurrenceRule in
                saveMilestone(
                    original: checklist,
                    title: title,
                    notes: notes,
                    dueDate: dueDate,
                    remind: remind,
                    items: items,
                    isDone: isDone,
                    tags: tags,
                    recurrenceRule: recurrenceRule
                )
            }
        }
        .sheet(item: $editingSimple) { checklist in
            AddSimpleChecklistView(
                checklist: checklist,
                theme: theme
            ) { title, notes, dueDate, remind, tags, recurrenceRule in
                saveSimple(
                    original: checklist,
                    title: title,
                    notes: notes,
                    dueDate: dueDate,
                    remind: remind,
                    tags: tags,
                    recurrenceRule: recurrenceRule
                )
            }
        }
    }

    private var eventDates: Set<Date> {
        let milestoneDates = milestones.compactMap { $0.dueDate }
        let checklistDates = checklists.compactMap { $0.dueDate }
        return Set(milestoneDates + checklistDates)
    }

    // MARK: - Actions
    
    private func saveMilestone(
        original: Checklist?,
        title: String,
        notes: String?,
        dueDate: Date?,
        remind: Bool,
        items: [ChecklistItem],
        isDone: Bool,
        tags: [Tag],
        recurrenceRule: String?
    ) {
        let checklist: Checklist
        if let original {
            checklist = original
            checklist.title = title
            checklist.notes = notes
            checklist.dueDate = dueDate
            checklist.remind = remind
            checklist.isDone = isDone
            checklist.tags = tags
            checklist.recurrenceRule = recurrenceRule
        } else {
            checklist = Checklist(
                title: title,
                notes: notes,
                dueDate: dueDate,
                remind: remind,
                items: [],
                tags: tags,
                recurrenceRule: recurrenceRule
            )
            checklist.isDone = isDone
            modelContext.insert(checklist)
        }

        let sortedItems = items.enumerated().map { idx, item -> ChecklistItem in
            item.position = idx
            item.checklist = checklist
            return item
        }
        checklist.items = sortedItems

        NotificationManager.shared.cancelNotification(for: checklist)
        NotificationManager.shared.scheduleNotification(for: checklist)

        editingMilestone = nil
        Task {
            await SyncManager.shared.sync(container: modelContext.container)
        }
    }

    private func saveSimple(
        original: SimpleChecklist?,
        title: String,
        notes: String?,
        dueDate: Date?,
        remind: Bool,
        tags: [Tag],
        recurrenceRule: String?
    ) {
        let checklist: SimpleChecklist
        if let original {
            checklist = original
            checklist.title = title
            checklist.notes = notes
            checklist.dueDate = dueDate
            checklist.remind = remind
            checklist.tags = tags
            checklist.recurrenceRule = recurrenceRule
        } else {
            checklist = SimpleChecklist(
                title: title,
                notes: notes,
                dueDate: dueDate,
                remind: remind,
                isDone: false,
                tags: tags,
                recurrenceRule: recurrenceRule
            )
            modelContext.insert(checklist)
        }

        NotificationManager.shared.cancelNotification(for: checklist)
        NotificationManager.shared.scheduleNotification(for: checklist)

        editingSimple = nil
        Task {
            await SyncManager.shared.sync(container: modelContext.container)
        }
    }

    private func isSameDay(_ date1: Date?, as date2: Date) -> Bool {
        guard let date1 else { return false }
        return calendar.isDate(date1, inSameDayAs: date2)
    }
}

struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let theme: Theme
    let milestones: [Checklist]
    let checklists: [SimpleChecklist]
    var animation: Namespace.ID
    let action: () -> Void

    private var calendar: Calendar { Calendar.current }

    // Helper method to check if two dates are the same day
    private func isSameDay(_ date1: Date?, as date2: Date) -> Bool {
        guard let date1 else { return false }
        return calendar.isDate(date1, inSameDayAs: date2)
    }

    var body: some View {
        let dailyMilestones = milestones.filter { isSameDay($0.dueDate, as: date) }
        let dailyChecklists = checklists.filter { isSameDay($0.dueDate, as: date) }
        
        let hasEvents = !dailyMilestones.isEmpty || !dailyChecklists.isEmpty
        let tagColor = dailyMilestones.compactMap { $0.tags.first?.color }.first
            ?? dailyChecklists.compactMap { $0.tags.first?.color }.first
            ?? theme.accent

        Button(action: action) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(theme.accent)
                        .matchedGeometryEffect(id: "selection", in: animation)
                        .shadow(color: theme.accent.opacity(0.3), radius: 4, x: 0, y: 2)
                } else if isToday {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(theme.accent.opacity(0.5), lineWidth: 1.5)
                }
                
                VStack(spacing: 4) {
                    Text("\(calendar.component(.day, from: date))")
                        .font(.callout)
                        .fontWeight(isSelected || isToday ? .semibold : .regular)
                        .foregroundStyle(isSelected ? .white : (isToday ? theme.accent : theme.primary))
                    
                    if hasEvents {
                        Circle()
                            .fill(isSelected ? .white : tagColor)
                            .frame(width: 4, height: 4)
                    } else {
                        Circle()
                            .fill(.clear)
                            .frame(width: 4, height: 4)
                    }
                }
            }
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }


}

#Preview {
    CalendarView(theme: .default)
        .modelContainer(for: [Checklist.self, SimpleChecklist.self, Tag.self], inMemory: true)
}
