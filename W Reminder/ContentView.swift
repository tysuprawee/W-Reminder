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
    @Query private var tags: [Tag]

    @State private var showingAddChecklist = false
    @State private var editingChecklist: Checklist?
    @State private var showPermissionAlert = false
    @State private var sortOption: SortOption = .creation
    @State private var filterTag: Tag? = nil // nil = all

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
                                    withAnimation { filterTag = nil }
                                } label: {
                                    if filterTag == nil {
                                        Label("All Tags", systemImage: "checkmark")
                                    } else {
                                        Text("All Tags")
                                    }
                                }
                                ForEach(tags) { tag in
                                    Button {
                                        withAnimation { filterTag = tag }
                                    } label: {
                                        if filterTag == tag {
                                            Label(tag.name, systemImage: "checkmark")
                                        } else {
                                            HStack {
                                                Circle().fill(tag.color).frame(width: 8, height: 8)
                                                Text(tag.name)
                                            }
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
                        guard let filterTag else { return true }
                        return $0.tags.contains(filterTag)
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
                ) { title, notes, dueDate, remind, items, isDone, tags in
                    saveChecklist(
                        original: editingChecklist,
                        title: title,
                        notes: notes,
                        dueDate: dueDate,
                        remind: remind,
                        items: items,
                        isDone: isDone,
                        tags: tags
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
        tags: [Tag]
    ) {
        let checklist: Checklist
        if let original {
            checklist = original
            checklist.title = title
            checklist.notes = notes
            checklist.remind = remind
            checklist.isDone = isDone
            checklist.tags = tags
        } else {
            checklist = Checklist(
                title: title,
                notes: notes,
                dueDate: dueDate,
                remind: remind,
                items: [],
                tags: tags
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
    @Environment(\.modelContext) private var modelContext
    @Query private var tags: [Tag]

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var dueDate: Date? = nil
    @State private var remind: Bool = true
    @State private var isSettingDueDate: Bool = false
    @State private var items: [ChecklistItem] = [ChecklistItem(text: "New item", position: 0)]
    @State private var isDone: Bool = false
    @State private var selectedTags: [Tag] = []
    
    // Custom Tag Creation State
    @State private var showingCreateTag = false
    @State private var newTagName = ""
    @State private var newTagColor = Color.blue

    var checklist: Checklist?
    let theme: Theme
    var onSave: (String, String?, Date?, Bool, [ChecklistItem], Bool, [Tag]) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                theme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 24) {
                            titleSection
                            notesSection
                            tagSelectionSection
                            deadlineSection
                            itemsSection
                        }
                        .padding(.vertical)
                    }
                }

                // Bottom Action Bar
                bottomBar
            }
            .navigationTitle(checklist == nil ? "New Milestone" : "Edit Milestone")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingCreateTag) {
                NavigationStack {
                    VStack(spacing: 24) {
                        Circle()
                            .fill(newTagColor)
                            .frame(width: 80, height: 80)
                            .shadow(radius: 5)
                        
                        TextField("Tag Name", text: $newTagName)
                            .font(.title2)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                        
                        CustomColorPicker(selection: $newTagColor)
                        
                        Spacer()
                    }
                    .padding(.top)
                    .navigationTitle("New Tag")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showingCreateTag = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Create") {
                                let tag = Tag(name: newTagName, colorHex: newTagColor.toHex())
                                modelContext.insert(tag)
                                if selectedTags.count < 3 {
                                    selectedTags.append(tag)
                                }
                                showingCreateTag = false
                                newTagName = ""
                            }
                            .disabled(newTagName.isEmpty)
                        }
                    }
                }
                .presentationDetents([.fraction(0.6), .large])
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
                    items = [ChecklistItem(text: "", position: 0)]
                }
                selectedTags = checklist.tags
            } else {
                // Explicitly reset ALL state for new tasks
                title = ""
                notes = ""
                dueDate = nil
                remind = true
                isSettingDueDate = false
                isDone = false
                items = [ChecklistItem(text: "New item", position: 0)]
                selectedTags = []
            }
        }
    }

    // MARK: - Subviews

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Title")
                .font(.headline)
                .foregroundStyle(theme.secondary)
            TextField("What needs to be done?", text: $title)
                .font(.title2.bold())
                .padding()
                .background(theme.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal)
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.headline)
                .foregroundStyle(theme.secondary)
            TextField("Add details...", text: $notes, axis: .vertical)
                .lineLimit(3...6)
                .padding()
                .background(theme.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal)
    }

    private var tagSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tags")
                .font(.headline)
                .foregroundStyle(theme.secondary)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(tags) { tag in
                            Button {
                                withAnimation {
                                    if selectedTags.contains(where: { $0.id == tag.id }) {
                                        selectedTags.removeAll { $0.id == tag.id }
                                    } else {
                                        if selectedTags.count < 3 {
                                            selectedTags.append(tag)
                                        }
                                    }
                                }
                            } label: {
                                Text(tag.name)
                                    .font(.caption.bold())
                                    .foregroundStyle(isDarkColor(tag.color) ? .white : .black)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(tag.color)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(theme.accent, lineWidth: selectedTags.contains(where: { $0.id == tag.id }) ? 3 : 0)
                                    )
                                    .shadow(color: tag.color.opacity(0.3), radius: 2, y: 1)
                            }
                        }
                        
                        Button {
                            showingCreateTag = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.caption.bold())
                                .foregroundStyle(theme.accent)
                                .frame(width: 30, height: 30)
                                .background(
                                    Circle()
                                        .stroke(theme.accent, style: StrokeStyle(lineWidth: 1, dash: [4]))
                                )
                        }
                }
                .padding(.horizontal)
            }
        }
    }

    private var deadlineSection: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Deadline")
                        .font(.headline)
                    if isSettingDueDate {
                        Text("Set a due date")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                CustomToggle(isOn: $isSettingDueDate.animation())
                    .onChange(of: isSettingDueDate) { oldValue, newValue in
                        if newValue { remind = true }
                    }
            }
            .padding()
            .background(theme.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            if isSettingDueDate {
                VStack(alignment: .leading, spacing: 16) {
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { dueDate ?? Date() },
                            set: { dueDate = $0 }
                        ),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.graphical)
                    .tint(theme.accent)
                    
                    Divider()
                    
                    HStack {
                        Label("Remind me", systemImage: "bell.fill")
                            .font(.subheadline)
                        Spacer()
                        CustomToggle(isOn: $remind)
                    }
                }
                .padding()
                .background(theme.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .transition(.scale.combined(with: .opacity))
            }
            
            HStack {
                Label("Mark as Done", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                Spacer()
                CustomToggle(isOn: $isDone)
            }
            .padding()
            .background(theme.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal)
    }

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Checklist Items")
                .font(.headline)
                .foregroundStyle(theme.secondary)
            
            ForEach($items) { $item in
                HStack {
                    Button {
                        item.isDone.toggle()
                        if !items.isEmpty && items.allSatisfy({ $0.isDone }) {
                            isDone = true
                        }
                    } label: {
                        Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(item.isDone ? theme.accent : .secondary)
                    }
                    
                    TextField("Item", text: $item.text)
                        .padding(.vertical, 8)
                    
                    if items.count > 1 {
                        Button {
                            withAnimation {
                                if let idx = items.firstIndex(where: { $0.id == item.id }) {
                                    items.remove(at: idx)
                                }
                            }
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundStyle(.red.opacity(0.7))
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(theme.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            Button {
                withAnimation {
                    let newPos = (items.map { $0.position }.max() ?? -1) + 1
                    items.append(ChecklistItem(text: "", position: newPos))
                }
            } label: {
                Label("Add Item", systemImage: "plus")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(theme.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(theme.accent)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 100)
    }

    private var bottomBar: some View {
        VStack {
            Spacer()
            HStack(spacing: 16) {
                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.headline)
                        .foregroundStyle(theme.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                
                Button {
                    guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    onSave(
                        title,
                        notes.isEmpty ? nil : notes,
                        isSettingDueDate ? (dueDate ?? Date()) : nil,
                        isSettingDueDate ? remind : false,
                        items.filter { !$0.text.isEmpty },
                        isDone,
                        selectedTags
                    )
                    dismiss()
                } label: {
                    Text("Save")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: theme.accent.opacity(0.3), radius: 10, y: 5)
                }
            }
            .padding()
            .background(
                LinearGradient(colors: [theme.background.opacity(0), theme.background], startPoint: .top, endPoint: .bottom)
            )
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
                Text(checklist.title)
                    .font(.headline)
                
                // Multi-Tag Display
                HStack(spacing: 4) {
                    ForEach(checklist.tags.prefix(3)) { tag in
                        Text(tag.name)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(isDarkColor(tag.color) ? .white : .black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(tag.color)
                            .clipShape(Capsule())
                    }
                    if checklist.tags.count > 3 {
                        Text("+\(checklist.tags.count - 3)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
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

fileprivate extension View {
    func isDarkColor(_ color: Color) -> Bool {
        return true 
    }
}
