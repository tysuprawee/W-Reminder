//
//  ContentView.swift
//  W Reminder
//
//  Created by Suprawee Pongpeeradech on 11/20/25.
//

import SwiftUI
import SwiftData
import UserNotifications
import UIKit

struct MilestoneView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Checklist.createdAt, order: .forward) private var checklists: [Checklist]

    @State private var showingAddChecklist = false
    @State private var editingChecklist: Checklist?
    @State private var showPermissionAlert = false
    @State private var sortOption: SortOption = .creation
    @State private var filterCategory: Category? = nil // nil = all

    enum SortOption: Identifiable, CaseIterable {
        case creation
        case earliestDue
        case latestDue

        var id: Self { self }
    }

    let theme: Theme

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        theme.background.opacity(0.85),
                        theme.primary.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Custom Header
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Milestones")
                                .font(.system(size: 34, weight: .bold))
                            
                            Text("Stay on top of things")
                                .font(.subheadline)
                                .foregroundStyle(theme.secondary)
                        }
                        
                        Spacer()
                        
                        // Custom Filter Button
                        Menu {
                            // Filter Section
                            Section("Filter") {
                                Button {
                                    withAnimation { filterCategory = nil }
                                } label: {
                                    if filterCategory == nil {
                                        Label("All Categories", systemImage: "checkmark")
                                    } else {
                                        Text("All Categories")
                                    }
                                }
                                ForEach(Category.allCases) { category in
                                    Button {
                                        withAnimation { filterCategory = category }
                                    } label: {
                                        if filterCategory == category {
                                            Label(category.rawValue, systemImage: "checkmark")
                                        } else {
                                            Text(category.rawValue)
                                        }
                                    }
                                }
                            }

                            // Sort Section
                            Section("Sort") {
                                Picker("Sort By", selection: $sortOption) {
                                    Label("Creation Date", systemImage: "clock").tag(SortOption.creation)
                                    Label("Earliest Due", systemImage: "arrow.down").tag(SortOption.earliestDue)
                                    Label("Latest Due", systemImage: "arrow.up").tag(SortOption.latestDue)
                                }
                            }
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                                .font(.headline)
                                .foregroundStyle(theme.primary)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(theme.accent.opacity(0.2), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                    .background(
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .ignoresSafeArea()
                    )

                    // List Content
                    let active = checklists.filter { !$0.isDone }
                    let filteredActive = active.filter {
                        guard let filterCategory else { return true }
                        return $0.category == filterCategory.rawValue
                    }
                    let sortedActive = sort(filteredActive)

                    if sortedActive.isEmpty {
                        emptyState
                            .padding(.top, 40)
                    } else {
                        checklistList(active: sortedActive)
                            .padding(.top)
                    }

                    Spacer()
                }
                
                // Floating Action Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            showingAddChecklist = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.title.bold())
                                .foregroundStyle(.white)
                                .frame(width: 60, height: 60)
                                .background(
                                    Circle()
                                        .fill(theme.accent)
                                        .shadow(color: theme.accent.opacity(0.4), radius: 10, x: 0, y: 5)
                                )
                        }
                        .padding()
                    }
                }
            }
            // Hide standard navigation bar
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingAddChecklist) {
                AddChecklistView(
                    checklist: editingChecklist,
                    theme: theme
                ) { title, notes, dueDate, remind, items, isDone, category in
                    saveChecklist(
                        original: editingChecklist,
                        title: title,
                        notes: notes,
                        dueDate: dueDate,
                        remind: remind,
                        items: items,
                        isDone: isDone,
                        category: category
                    )
                }
            }
            .alert("Notifications are off", isPresented: $showPermissionAlert) {
                Button("Allow Now") {
                    NotificationManager.shared.requestAuthorization()
                    verifyNotificationPermission()
                }
                Button("Open Settings") {
                    openAppSettings()
                }
                Button("Maybe Later", role: .cancel) {}
            } message: {
                Text("Enable notifications in Settings to get reminder alerts.")
            }
        }
        .tint(theme.accent)
        .background(theme.background.ignoresSafeArea())
    }

    private func saveChecklist(
        original: Checklist?,
        title: String,
        notes: String?,
        dueDate: Date?,
        remind: Bool,
        items: [ChecklistItem],
        isDone: Bool,
        category: Category?
    ) {
        let checklist: Checklist
        if let original {
            checklist = original
            checklist.title = title
            checklist.notes = notes
            checklist.dueDate = dueDate
            checklist.remind = remind
            checklist.isDone = isDone
            checklist.category = category?.rawValue
        } else {
            checklist = Checklist(
                title: title,
                notes: notes,
                dueDate: dueDate,
                remind: remind,
                items: [],
                category: category
            )
            checklist.isDone = isDone
            modelContext.insert(checklist)
        }

        // sync items with relationship and preserve ordering
        let sortedItems = items.enumerated().map { idx, item -> ChecklistItem in
            item.position = idx
            item.checklist = checklist
            return item
        }
        checklist.items = sortedItems

        NotificationManager.shared.cancelNotification(for: checklist)
        NotificationManager.shared.scheduleNotification(for: checklist)
        verifyNotificationPermission()
        editingChecklist = nil
    }

    private func deleteChecklists(offsets: IndexSet, in source: [Checklist]) {
        withAnimation {
            for index in offsets {
                let checklist = source[index]
                NotificationManager.shared.cancelNotification(for: checklist)
                modelContext.delete(checklist)
            }
        }
    }

    private func verifyNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus != .authorized &&
                settings.authorizationStatus != .provisional {
                DispatchQueue.main.async {
                    showPermissionAlert = true
                }
            }
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Stay on top of things")
                .font(.title2.bold())
            Text("Create reminders with notes and get notified when they’re due.")
                .foregroundStyle(theme.secondary)
        }
    }

    private func checklistList(active: [Checklist]) -> some View {
        List {
            ForEach(active) { checklist in
                ChecklistRow(
                    checklist: checklist,
                    theme: theme,
                    onEdit: {
                        editingChecklist = checklist
                        showingAddChecklist = true
                    }
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
            .onDelete { offsets in
                deleteChecklists(offsets: offsets, in: active)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
    }

    private func sort(_ checklists: [Checklist]) -> [Checklist] {
        switch sortOption {
        case .creation:
            return checklists
        case .earliestDue:
            return checklists.sorted { lhs, rhs in
                guard let lDate = lhs.dueDate else { return false }
                guard let rDate = rhs.dueDate else { return true }
                return lDate < rDate
            }
        case .latestDue:
            return checklists.sorted { lhs, rhs in
                guard let lDate = lhs.dueDate else { return false }
                guard let rDate = rhs.dueDate else { return true }
                return lDate > rDate
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.badge")
                .font(.system(size: 44))
                .foregroundStyle(theme.accent)
                .symbolRenderingMode(.multicolor)

            Text("No checklists yet")
                .font(.headline)
            Text("Tap the + button to add your first checklist.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(theme.background.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(theme.accent.opacity(0.2), lineWidth: 1)
        )
    }
}

struct AddChecklistView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var dueDate: Date? = nil
    @State private var remind: Bool = true
    @State private var isSettingDueDate: Bool = false
    @State private var items: [ChecklistItem] = [ChecklistItem(text: "New item")]
    @State private var isDone: Bool = false
    @State private var selectedCategory: Category? = nil

    var checklist: Checklist?
    let theme: Theme
    var onSave: (String, String?, Date?, Bool, [ChecklistItem], Bool, Category?) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Checklist")) {
                    TextField("Title", text: $title)
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(1...4)
                    
                    Picker("Category", selection: $selectedCategory) {
                        Text("None").tag(Category?.none)
                        ForEach(Category.allCases) { category in
                            Label(category.rawValue, systemImage: category.icon)
                                .tag(Category?.some(category))
                        }
                    }

                    Toggle("Add deadline", isOn: $isSettingDueDate)
                    Toggle("Notify me", isOn: $remind)
                        .disabled(!isSettingDueDate)

                    if isSettingDueDate {
                        DatePicker(
                            "Due Date",
                            selection: Binding(
                                get: { dueDate ?? Date() },
                                set: { dueDate = $0 }
                            ),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .environment(\.timeZone, .current)
                        .opacity(remind ? 1 : 0.5)
                        .disabled(!remind)
                    }

                    Toggle("Mark as done", isOn: $isDone)
                }

                Section("Items") {
                    ForEach($items) { $item in
                        HStack {
                            Button {
                                item.isDone.toggle()
                            } label: {
                                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(item.isDone ? theme.accent : .secondary)
                            }
                            .buttonStyle(.plain)

                            TextField("Task", text: $item.text)
                        }
                    }
                    .onDelete { offsets in
                        items.remove(atOffsets: offsets)
                    }

                    Button {
                        let newPosition = (items.map { $0.position }.max() ?? -1) + 1
                        items.append(ChecklistItem(text: "New item", position: newPosition))
                    } label: {
                        Label("Add item", systemImage: "plus.circle")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(LinearGradient(
                colors: [theme.background.opacity(0.8), theme.accent.opacity(0.1)],
                startPoint: .top,
                endPoint: .bottom
            ))
            .navigationTitle(checklist == nil ? "New Checklist" : "Edit Checklist")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else {
                            return
                        }
                        onSave(
                            title,
                            notes.isEmpty ? nil : notes,
                            isSettingDueDate ? (dueDate ?? Date()) : nil,
                            isSettingDueDate ? remind : false,
                            items.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty },
                            isDone,
                            selectedCategory
                        )
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .onAppear {
            if let checklist {
                title = checklist.title
                notes = checklist.notes ?? ""
                dueDate = checklist.dueDate
                remind = checklist.remind
                isSettingDueDate = checklist.dueDate != nil
                isDone = checklist.isDone
                items = checklist.items.sorted { $0.position < $1.position }
                if items.isEmpty {
                    items = [ChecklistItem(text: "New item")]
                }
                if let raw = checklist.category {
                    selectedCategory = Category(rawValue: raw)
                }
            }
        }
    }
}

#Preview {
    MilestoneView(theme: .default)
        .modelContainer(for: [Checklist.self, ChecklistItem.self], inMemory: true)
}

struct ChecklistRow: View {
    let checklist: Checklist
    let theme: Theme
    var onEdit: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                if let raw = checklist.category, let cat = Category(rawValue: raw) {
                    Text(cat.rawValue)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(cat.color.opacity(0.2))
                        .foregroundStyle(cat.color)
                        .clipShape(Capsule())
                }
                Text(checklist.title)
                    .font(.headline)
                Spacer()
                if let due = checklist.dueDate {
                    Text(due, format: .dateTime.hour().minute())
                        .font(.subheadline.bold())
                        .foregroundStyle(theme.accent)
                }
            }

            if let due = checklist.dueDate {
                HStack(spacing: 6) {
                    Text(due, format: .dateTime.day().month().year())
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(timeRemaining(until: due))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let notes = checklist.notes, !notes.isEmpty {
                Text(notes)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: progress)
                .tint(theme.accent)

            HStack {
                Text("\(completedCount)/\(checklist.items.count) done")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Edit") { onEdit() }
                    .font(.caption)
            }
        }
        .padding()
        .background(theme.background.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .animation(.easeInOut, value: checklist.isDone)
    }

    private var completedCount: Int {
        checklist.items.filter { $0.isDone }.count
    }

    private var progress: Double {
        guard !checklist.items.isEmpty else { return 0 }
        return Double(completedCount) / Double(checklist.items.count)
    }

    private func timeRemaining(until date: Date) -> String {
        let remaining = date.timeIntervalSinceNow
        if remaining < 0 {
            let overdue = -remaining
            if overdue < 60 {
                return "Just now"
            } else if overdue < 3600 {
                let minutes = Int(ceil(overdue / 60))
                return "\(minutes) min ago"
            } else if overdue < 86_400 {
                let hours = Int(ceil(overdue / 3600))
                return "\(hours) hour\(hours == 1 ? "" : "s") ago"
            } else {
                let days = Int(ceil(overdue / 86_400))
                return "\(days) day\(days == 1 ? "" : "s") ago"
            }
        }
        let hours = remaining / 3600
        if hours >= 24 {
            let days = Int(hours / 24)
            return "\(days) day\(days == 1 ? "" : "s") left"
        } else if hours >= 1 {
            let h = Int(ceil(hours))
            return "\(h) hour\(h == 1 ? "" : "s") left"
        } else if remaining >= 60 {
            let minutes = Int(ceil(remaining / 60))
            return "\(minutes) min left"
        } else {
            return "Now"
        }
    }
}
