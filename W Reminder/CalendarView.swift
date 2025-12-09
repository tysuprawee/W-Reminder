//
//  CalendarView.swift
//  W Reminder
//
//  Created by Suprawee Pongpeeradech on 11/20/25.
//

import SwiftUI
import SwiftData

struct CalendarView: View {
    let theme: Theme

    @Query(sort: \Checklist.dueDate, order: .forward) private var milestones: [Checklist]
    @Query(sort: \SimpleChecklist.dueDate, order: .forward) private var checklists: [SimpleChecklist]

    @State private var monthOffset = 0 // current month offset
    @State private var selectedDate: Date = Date()

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
                        // Header
                        HStack {
                            Text(calendarDate, format: .dateTime.month(.wide).year())
                                .font(.title2.bold())
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
                        
                        // Days Header
                        HStack {
                            ForEach(weekDays, id: \.self) { day in
                                Text(day)
                                    .font(.caption.bold())
                                    .foregroundStyle(theme.secondary)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        
                        // Days Grid
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                            // Blank spaces for start of month
                            if let first = daysInMonth.first {
                                let weekday = calendar.component(.weekday, from: first)
                                ForEach(0..<(weekday - 1), id: \.self) { _ in
                                    Color.clear
                                }
                            }
                            
                            ForEach(daysInMonth, id: \.self) { date in
                                let isSelected = isSameDay(date, as: selectedDate)
                                let isToday = isSameDay(date, as: Date())
                                let hasEvents = eventDates.contains { 
                                    calendar.isDate($0, inSameDayAs: date) 
                                }
                                
                                Button {
                                    withAnimation(.snappy) {
                                        selectedDate = date
                                    }
                                } label: {
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
                                                    .fill(isSelected ? .white : theme.accent)
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
                        .transition(.move(edge: monthOffset > 0 ? .trailing : .leading).combined(with: .opacity))
                        .id(monthOffset) // Triggers transition when month changes
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
                    )
                    .padding()

                    Divider()

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
                                        HStack {
                                            Image(systemName: milestone.isDone ? "flag.checkered" : "flag")
                                            Text(milestone.title)
                                            Spacer()
                                            if let catRaw = milestone.category, let cat = Category(rawValue: catRaw) {
                                               Circle()
                                                    .fill(cat.color)
                                                    .frame(width: 8, height: 8)
                                            }
                                        }
                                        .padding()
                                        .background(theme.background.opacity(0.8))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .padding(.horizontal)
                                    }
                                }

                                if !dailyChecklists.isEmpty {
                                    Text("Checklists")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(theme.accent)
                                        .padding(.horizontal)
                                    
                                    ForEach(dailyChecklists) { checklist in
                                        HStack {
                                            Image(systemName: checklist.isDone ? "checkmark.circle.fill" : "circle")
                                            Text(checklist.title)
                                            Spacer()
                                            if let catRaw = checklist.category, let cat = Category(rawValue: catRaw) {
                                               Circle()
                                                    .fill(cat.color)
                                                    .frame(width: 8, height: 8)
                                            }
                                        }
                                        .padding()
                                        .background(theme.background.opacity(0.8))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .padding(.horizontal)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Calendar")
        }
    }

    private var eventDates: Set<Date> {
        let milestoneDates = milestones.compactMap { $0.dueDate }
        let checklistDates = checklists.compactMap { $0.dueDate }
        return Set(milestoneDates + checklistDates)
    }

    private func isSameDay(_ date1: Date?, as date2: Date) -> Bool {
        guard let date1 else { return false }
        return calendar.isDate(date1, inSameDayAs: date2)
    }
}

#Preview {
    CalendarView(theme: .default)
        .modelContainer(for: [Checklist.self, SimpleChecklist.self], inMemory: true)
}
