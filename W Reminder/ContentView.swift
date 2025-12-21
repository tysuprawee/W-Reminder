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
    @State private var sortOption: SortOption = .manual
    @State private var filterTag: Tag? = nil // nil = all
    @State private var showOnlyStarred = false
    @State private var refreshID = UUID() // Force refresh TimelineView

    enum SortOption: Identifiable, CaseIterable {
        case manual
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
                        
                        // Star Filter Button
                        Button {
                            withAnimation {
                                showOnlyStarred.toggle()
                            }
                        } label: {
                            Image(systemName: showOnlyStarred ? "star.fill" : "star")
                                .font(.headline)
                                .foregroundStyle(showOnlyStarred ? theme.accent : theme.primary)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(theme.accent.opacity(showOnlyStarred ? 0.5 : 0.2), lineWidth: showOnlyStarred ? 2 : 1)
                                )
                        }
                        
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
                                    Label("Manual Order", systemImage: "arrow.up.arrow.down").tag(SortOption.manual)
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

                    // Main List with Live Timer
                VStack(spacing: 0) {
                     TimelineView(.everyMinute) { context in
                         let _ = context.date // Force view update on timeline changes
                         let active = checklists.filter { !$0.isDone }
                         let filteredActive = active.filter {
                             guard let filterTag else { return true }
                             return $0.tags.contains(where: { $0.id == filterTag.id })
                         }
                         let starredFiltered = showOnlyStarred ? filteredActive.filter { $0.isStarred } : filteredActive
                         let sortedActive = sort(starredFiltered)
                         
                         if sortedActive.isEmpty {
                             emptyState
                                 .padding(.top, 40)
                         } else {
                             checklistList(active: sortedActive)
                                 .padding(.top)
                         }
                     }
                }
                .padding(.horizontal)
                .padding(.bottom, 80)
                
                
                Spacer()
            }
                
                // Floating Action Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            editingChecklist = nil
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
            // Sheet for Creating New Checklist
            .sheet(isPresented: $showingAddChecklist) {
                AddChecklistView(
                    checklist: nil,
                    theme: theme
                ) { title, notes, dueDate, remind, items, isDone, tags, recurrenceRule in
                    saveChecklist(
                        original: nil,
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
            // Sheet for Editing Existing Checklist
            .sheet(item: $editingChecklist) { checklist in
                AddChecklistView(
                    checklist: checklist,
                    theme: theme
                ) { title, notes, dueDate, remind, items, isDone, tags, recurrenceRule in
                    saveChecklist(
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
            .alert("Notifications are off", isPresented: $showPermissionAlert) {
                Button("Allow Now") {
                    NotificationManager.shared.requestAuthorization { granted in
                        if granted {
                            showPermissionAlert = false
                        }
                    }
                }
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Maybe Later", role: .cancel) {
                    showPermissionAlert = false
                }
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
        tags: [Tag],
        recurrenceRule: String?
    ) {
        let checklist: Checklist
        if let original {
            checklist = original
            checklist.title = title
            checklist.notes = notes
            checklist.remind = remind
            checklist.isDone = isDone
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
        
        // Auto-sync
        Task {
            await SyncManager.shared.sync(container: modelContext.container)
        }
    }

    private func deleteChecklists(offsets: IndexSet, in source: [Checklist]) {
        withAnimation {
            for index in offsets {
                let checklist = source[index]
                NotificationManager.shared.cancelNotification(for: checklist)
                SyncManager.shared.registerDeletion(of: checklist, context: modelContext)
                modelContext.delete(checklist)
            }
            // Auto-sync on Delete
            try? modelContext.save()
            Task {
                await SyncManager.shared.sync(container: modelContext.container)
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
                        print("DEBUG: Editing checklist \(checklist.title)")
                        editingChecklist = checklist
                    }
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
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
            .onDelete { offsets in
                deleteChecklists(offsets: offsets, in: active)
            }
            .onMove { from, to in
                moveChecklists(from: from, to: to, active: active)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
        .refreshable {
            // Trigger haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            
            // Force refresh by updating refreshID
            refreshID = UUID()
            
            // Small delay for visual feedback
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        .id(refreshID) // Force view refresh when refreshID changes
    }

    private func moveChecklists(from source: IndexSet, to destination: Int, active: [Checklist]) {
        var sortedItems = active
        sortedItems.move(fromOffsets: source, toOffset: destination)
        
        // Update userOrder for all items to reflect new position
        for (index, item) in sortedItems.enumerated() {
            item.userOrder = index
        }
    }

    private func sort(_ checklists: [Checklist]) -> [Checklist] {
        switch sortOption {
        case .manual:
            return checklists.sorted { $0.userOrder < $1.userOrder }
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
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(theme.accent.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
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
    @State private var recurrenceRule: String? = nil
    @State private var detectedDate: SmartDateResult? = nil
    
    // Custom Tag Creation State
    @State private var showingNewTagSheet = false
    @State private var showingErrorAlert = false

    var checklist: Checklist?
    let theme: Theme
    var onSave: (String, String?, Date?, Bool, [ChecklistItem], Bool, [Tag], String?) -> Void

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
                            recurrenceSection
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

        }
        .sheet(isPresented: $showingNewTagSheet) {
            NavigationStack {
                TagEditView(theme: theme) { name, color in
                    let hexString = color.toHex()
                    let newTag = Tag(name: name, colorHex: hexString)
                    modelContext.insert(newTag)
                    try? modelContext.save()
                    selectedTags.append(newTag)
                    showingNewTagSheet = false
                }
            }
        }
        .alert("Title Required", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please enter a title for your milestone.")
        }
        .onAppear {
            print("DEBUG: AddChecklistView appeared. Checklist: \(String(describing: checklist?.title)), ID: \(String(describing: checklist?.id))")
            if let checklist {
                print("DEBUG: Loading existing checklist: \(checklist.title)")
                title = checklist.title
                notes = checklist.notes ?? ""
                dueDate = checklist.dueDate
                remind = checklist.remind
                isSettingDueDate = checklist.dueDate != nil
                isDone = checklist.isDone
                items = checklist.items.sorted { $0.position < $1.position }
                recurrenceRule = checklist.recurrenceRule
                if items.isEmpty {
                    items = [ChecklistItem(text: "", position: 0)]
                }
                selectedTags = checklist.tags
                print("DEBUG: Loaded checklist tags: \(checklist.tags.map { $0.name }) IDs: \(checklist.tags.map { $0.id })")
                print("DEBUG: Query tags count: \(tags.count)")
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
                recurrenceRule = nil
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
            
            if let detected = detectedDate {
                Button {
                    dueDate = detected.date
                    title = detected.cleanedText
                    isSettingDueDate = true
                    remind = true
                    detectedDate = nil
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Set due date to \(detected.date.formatted(date: .abbreviated, time: .shortened))")
                    }
                    .font(.caption.bold())
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal)
                }
            }
        }
        .padding(.horizontal)
        .onChange(of: title) { oldValue, newValue in
            if let result = DateParser.shared.parse(newValue) {
                withAnimation { detectedDate = result }
            } else {
                withAnimation { detectedDate = nil }
            }
        }
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
                                    .background(
                                        Capsule()
                                            .fill(tag.color.opacity(0.85))
                                            .overlay(
                                                Capsule()
                                                    .fill(
                                                        LinearGradient(
                                                            colors: [.white.opacity(0.3), .clear],
                                                            startPoint: .top,
                                                            endPoint: .bottom
                                                        )
                                                    )
                                            )
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(selectedTags.contains(where: { $0.id == tag.id }) ? theme.accent : tag.color.opacity(0.4), lineWidth: selectedTags.contains(where: { $0.id == tag.id }) ? 3 : 1)
                                    )
                                    .shadow(color: tag.color.opacity(0.4), radius: 4, y: 2)
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    withAnimation {
                                        if let idx = selectedTags.firstIndex(where: { $0.id == tag.id }) {
                                            selectedTags.remove(at: idx)
                                        }
                                        modelContext.delete(tag)
                                    }
                                } label: {
                                    Label("Delete Tag", systemImage: "trash")
                                }
                            }
                        }
                        
                        Button {
                            showingNewTagSheet = true
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
                    .accessibilityIdentifier("deadlineToggle")
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
                    .frame(maxHeight: 400) // Constrain height to prevent NaN layout issues
                    
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

    private var recurrenceSection: some View {
         VStack(alignment: .leading, spacing: 12) {
             Text("Repeat")
                 .font(.headline)
                 .foregroundStyle(theme.secondary)
                 .padding(.horizontal)
             
             HStack {
                 Image(systemName: "repeat")
                     .foregroundStyle(theme.accent)
                 
                 Picker("Recurrence", selection: $recurrenceRule) {
                     Text("Never").tag(String?.none)
                     Text("Daily").tag(String?.some("daily"))
                     Text("Weekly").tag(String?.some("weekly"))
                     Text("Monthly").tag(String?.some("monthly"))
                 }
                 .pickerStyle(.menu)
                 .accentColor(theme.primary)
                 
                 Spacer()
             }
             .padding()
             .background(theme.primary.opacity(0.05))
             .clipShape(RoundedRectangle(cornerRadius: 16))
             .padding(.horizontal)
         }
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
                        // Auto-update parent status
                        isDone = !items.isEmpty && items.allSatisfy({ $0.isDone })
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
                                    // Re-evaluate completion status after deletion
                                    if !items.isEmpty {
                                        isDone = items.allSatisfy({ $0.isDone })
                                    } else {
                                        // If no items left, do we auto-complete? Or keep manual?
                                        // Let's keep existing state or maybe false?
                                        // Usually empty list isn't "done" by task standards, but user might manually toggle.
                                        // Let's leave it alone if empty, only update if items exist.
                                    }
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
                    items.append(ChecklistItem(text: "New item", position: newPos))
                    // Adding a new (incomplete) item always makes the list incomplete
                    isDone = false
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
                    if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        showingErrorAlert = true
                        return
                    }
                    onSave(
                        title,
                        notes,
                        isSettingDueDate ? dueDate : nil,
                        remind,
                        items.filter { !$0.text.isEmpty },
                        isDone,
                        selectedTags,
                        recurrenceRule
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
        .modelContainer(for: [Checklist.self, ChecklistItem.self, Tag.self], inMemory: true)
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
                            .background(
                                Capsule()
                                    .fill(tag.color.opacity(0.85))
                                    .overlay(
                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    colors: [.white.opacity(0.3), .clear],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                    )
                            )
                            .overlay(
                                Capsule()
                                    .stroke(tag.color.opacity(0.4), lineWidth: 0.5)
                            )
                            .shadow(color: tag.color.opacity(0.3), radius: 2, y: 1)
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
                        .foregroundStyle(theme.secondary)
                    Spacer()
                    Text(timeRemaining(until: due))
                        .font(.footnote)
                        .foregroundStyle(theme.secondary)
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
                
                if let dueDate = checklist.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text(timeRemaining(until: dueDate))
                            .font(.caption)
                            .accessibilityIdentifier("timeRemainingLabel")
                    }
                    .foregroundStyle(deadlineColor(for: dueDate))
                }
                
                Button("Edit") { onEdit() }
                    .font(.caption)
            }
        }
        .padding()
        .background(cardBackground)
        .shadow(color: checklist.isStarred ? theme.accent.opacity(0.25) : .black.opacity(0.05), radius: checklist.isStarred ? 8 : 5, x: 0, y: 2)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: checklist.isStarred)
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
        }
    }
    
    private func deadlineColor(for dueDate: Date) -> Color {
        let now = Date()
        let timeRemaining = dueDate.timeIntervalSince(now)
        
        if timeRemaining < 0 {
            // Past due
            return .red
        } else if timeRemaining < 86400 { // Less than 24 hours
            return .yellow
        } else {
            // More than 1 day
            return theme.secondary
        }
    }

    private var completedCount: Int {
        checklist.items.filter { $0.isDone }.count
    }

    private var progress: Double {
        guard !checklist.items.isEmpty else { return 0 }
        return Double(completedCount) / Double(checklist.items.count)
    }
    
    // Background styling helper
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(
                checklist.isStarred 
                    ? theme.accent.opacity(0.12)
                    : (theme.isDark ? Color.white.opacity(0.05) : theme.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(checklist.isStarred ? theme.accent : Color.clear, lineWidth: checklist.isStarred ? 2.5 : 0)
            )
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
