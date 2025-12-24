import SwiftUI
import SwiftData
import UserNotifications
import UIKit
import WidgetKit

struct SimpleChecklistView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SimpleChecklist.createdAt, order: .forward) private var checklists: [SimpleChecklist]
    @Query private var tags: [Tag]

    @State private var showingAdd = false
    @State private var editing: SimpleChecklist?
    @State private var showPermissionAlert = false
    @AppStorage("checklistSortOption") private var sortOption: SortOption = .manual
    @State private var filterTag: Tag? = nil // nil = all
    @State private var showOnlyStarred = false
    @State private var refreshID = UUID() // Force refresh TimelineView
    @State private var showStreakInfo = false
    @AppStorage("isHapticsEnabled") private var isHapticsEnabled = true // Listen to setting
    
    // Batch Completion State
    @State private var pendingCompletionIDs: Set<UUID> = []
    @State private var batchCompletionTask: Task<Void, Never>? = nil

    enum SortOption: String, CaseIterable {
        case manual
        case earliestDue
        case latestDue
    }

    let theme: Theme

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        theme.background.opacity(0.85),
                        theme.secondary.opacity(0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Custom Header
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Checklists")
                                .font(.system(size: 34, weight: .bold))
                            
                            Text("Single-step tasks")
                                .font(.subheadline)
                                .foregroundStyle(theme.secondary)
                        }
                        
                        Spacer()
                        
                        // Streak Counter
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(StreakManager.shared.isStreakActiveToday ? .orange : .gray)
                            Text("\(StreakManager.shared.currentStreak)")
                                .fontWeight(.bold)
                                .contentTransition(.numericText())
                        }
                        .font(.headline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(StreakManager.shared.isStreakActiveToday ? Color.orange.opacity(0.5) : Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .onAppear { StreakManager.shared.checkStreak() }
                        .onTapGesture {
                            showStreakInfo = true
                        }
                        .sheet(isPresented: $showStreakInfo) {
                            ProfilePopupView(theme: theme)
                                .presentationDetents([.medium, .large])
                                .presentationDragIndicator(.visible)
                        }
                        .padding(.trailing, 8)
                        
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
                            let active = checklists.filter { !$0.isDone || pendingCompletionIDs.contains($0.id) }
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
                                list(active: sortedActive)
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
                            editing = nil
                            showingAdd = true
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
            // Sheet for Creating New Simple Checklist
            .sheet(isPresented: $showingAdd) {
                AddSimpleChecklistView(
                    checklist: nil,
                    theme: theme
                ) { title, notes, dueDate, remind, tags, recurrenceRule in
                    save(
                        original: nil,
                        title: title,
                        notes: notes,
                        dueDate: dueDate,
                        remind: remind,
                        tags: tags,
                        recurrenceRule: recurrenceRule
                    )
                }
            }
            // Sheet for Editing Existing Simple Checklist
            .sheet(item: $editing) { checklist in
                AddSimpleChecklistView(
                    checklist: checklist,
                    theme: theme
                ) { title, notes, dueDate, remind, tags, recurrenceRule in
                    save(
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

    private func save(
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
            checklist.updatedAt = Date() // Update timestamp for sync
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
        
        // Immediate persistence
        try? modelContext.save()

        NotificationManager.shared.cancelNotification(for: checklist)
        NotificationManager.shared.scheduleNotification(for: checklist)
        verifyNotificationPermission()
        editing = nil
        
        // Auto-sync on Save
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            WidgetCenter.shared.reloadAllTimelines()
            await SyncManager.shared.sync(container: modelContext.container, silent: true)
        }
    }

    private func delete(offsets: IndexSet, in source: [SimpleChecklist]) {
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
                 try? await Task.sleep(nanoseconds: 500_000_000)
                 WidgetCenter.shared.reloadAllTimelines()
                 await SyncManager.shared.sync(container: modelContext.container, silent: true)
            }
        }
    }

    private func list(active: [SimpleChecklist]) -> some View {
        List {
            ForEach(active) { checklist in
                SimpleChecklistRow(
                    checklist: checklist,
                    theme: theme,
                    isPendingCompletion: pendingCompletionIDs.contains(checklist.id),
                    onToggleDone: {
                        print("Tap Done: item=\(checklist.title)")
                        let isCurrentlyDone = checklist.isDone
                        let isPending = pendingCompletionIDs.contains(checklist.id)
                        
                        // If checking (Mark Done)
                        if !isCurrentlyDone && !isPending {
                            // 1. Add to Pending (Visually Checked)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                _ = pendingCompletionIDs.insert(checklist.id)
                            }
                            // Haptic
                            HapticManager.shared.play(.rigid)
                            
                            // 2. Schedule Batch Commit
                            batchCompletionTask?.cancel()
                            batchCompletionTask = Task {
                                // Wait for user to stop clicking
                                try? await Task.sleep(nanoseconds: 1_200_000_000) // 1.2s
                                guard !Task.isCancelled else { return }
                                
                                await commitPendingCompletions()
                            }
                        } 
                        // If Unchecking (Mark Undone) Or Unchecking a Pending Item
                        else if isCurrentlyDone || isPending {
                             // Correct Mistake Immediately
                             if isPending {
                                 // Just remove from pending, no DB write needed yet
                                 withAnimation {
                                     _ = pendingCompletionIDs.remove(checklist.id)
                                 }
                                 // If this was the last pending, cancel commit?
                                 if pendingCompletionIDs.isEmpty {
                                     batchCompletionTask?.cancel()
                                 }
                             } else {
                                 // Was actually written to DB, undo it
                                 checklist.isDone = false
                                 checklist.completedAt = nil
                                 checklist.updatedAt = Date()

                                 try? modelContext.save()
                                 WidgetCenter.shared.reloadAllTimelines()
                                 Task { await SyncManager.shared.sync(container: modelContext.container, silent: true) }
                             }
                        }
                    },
                    onEdit: {
                        print("DEBUG: Editing simple checklist \(checklist.title)")
                        editing = checklist
                    }
                ).listRowSeparator(.hidden)
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
                delete(offsets: offsets, in: active)
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
            HapticManager.shared.play(.medium)
            
            // Force refresh by updating refreshID
            refreshID = UUID()
            
            // Sync with Cloud
            await SyncManager.shared.sync(container: modelContext.container, silent: true)
            
            // Small delay for visual feedback
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        .id(refreshID) // Force view refresh when refreshID changes
    }

    private func commitPendingCompletions() async {
        guard !pendingCompletionIDs.isEmpty else { return }
        
        let idsToCommit = pendingCompletionIDs
        
        print("Committing \(idsToCommit.count) items...")
        
        await MainActor.run {
            var tasksCompleted = 0
            
            for id in idsToCommit {
                if let checklist = checklists.first(where: { $0.id == id }) {
                    // Safety check if already done
                    if !checklist.isDone {
                        checklist.isDone = true
                        checklist.completedAt = Date()
                        checklist.updatedAt = Date()

                        
                        // Cancel Notifications
                        NotificationManager.shared.cancelNotification(for: checklist)
                        
                        tasksCompleted += 1
                        
                        // Recurrence logic here
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
                }
            }
            
            // Grant XP for Batch (Manual LevelManager call if StreakManager doesn't handle XP)
            // Assuming StreakManager handles XP on increment?
            // Let's just increment Streak for each.
            for _ in 0..<tasksCompleted {
                StreakManager.shared.incrementStreak()
            }
            
            // Save & Sync ONCE
            try? modelContext.save()
            WidgetCenter.shared.reloadAllTimelines()
            Task { await SyncManager.shared.sync(container: modelContext.container, silent: true) }
            
            // Clear IDs
            withAnimation {
                pendingCompletionIDs.removeAll()
            }
        }
    }

    private func moveChecklists(from source: IndexSet, to destination: Int, active: [SimpleChecklist]) {
        var sortedItems = active
        sortedItems.move(fromOffsets: source, toOffset: destination)
        
        for (index, item) in sortedItems.enumerated() {
            item.userOrder = index
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Quick checklists")
                .font(.title2.bold())
            Text("Single-step tasks with optional reminders.")
                .foregroundStyle(theme.secondary)
        }
    }

    private func sort(_ checklists: [SimpleChecklist]) -> [SimpleChecklist] {
        switch sortOption {
        case .manual:
            return checklists.sorted { $0.userOrder < $1.userOrder }
        case .earliestDue: // creation is gone
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
            Image(systemName: "checklist")
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
    

}

struct AddSimpleChecklistView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var tags: [Tag]

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var dueDate: Date? = nil
    @State private var remind: Bool = true
    @State private var isSettingDueDate: Bool = false
    @State private var selectedTags: [Tag] = []
    @State private var recurrenceRule: String? = nil
    @State private var detectedDate: SmartDateResult? = nil
    
    // Custom Tag Creation State
    @State private var showingNewTagSheet = false
    @State private var showingErrorAlert = false

    var checklist: SimpleChecklist?
    let theme: Theme
    var onSave: (String, String?, Date?, Bool, [Tag], String?) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                theme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 24) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Title")
                                    .font(.headline)
                                    .foregroundStyle(theme.secondary)
                                TextField("What to do?", text: $title)
                                    .font(.title2.bold())
                                    .padding()
                                    .background(theme.primary.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .onChange(of: title) { oldValue, newValue in
                                        if let result = DateParser.shared.parse(newValue) {
                                            withAnimation { detectedDate = result }
                                        } else {
                                            withAnimation { detectedDate = nil }
                                        }
                                    }
                                
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

                            // Notes Input
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

                            // Tag Selection
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Highlighters")
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
                                                                                // "Add Tag" Button
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

                            // Toggles Section
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
                                            if newValue { 
                                                remind = true 
                                                if dueDate == nil { dueDate = Date() }
                                            }
                                        }
                                }
                                .padding()
                                .background(theme.primary.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 16))

                                if isSettingDueDate {
                                    VStack(spacing: 12) {
                                        DatePicker(
                                            "Due Date",
                                            selection: Binding(
                                                get: { dueDate ?? Date() },
                                                set: { dueDate = $0 }
                                            ),
                                            displayedComponents: [.date, .hourAndMinute]
                                        )
                                        .datePickerStyle(.graphical)
                                        .tint(theme.accent)
                                        .padding(.horizontal)
                                        
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
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                            
                            // Recurrence Section
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
                                
                                if let rule = recurrenceRule {
                                    Text(RecurrenceHelper.description(for: rule, date: isSettingDueDate ? (dueDate ?? Date()) : Date()))
                                        .font(.caption)
                                        .foregroundStyle(theme.accent)
                                        .padding(.horizontal, 32)
                                        .transition(.opacity)
                                }
                            }
                            .padding(.bottom, 80)
                        }
                        .padding(.vertical)
                    }
                }

                // Bottom Action Bar
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
                                notes.isEmpty ? nil : notes,
                                isSettingDueDate ? (dueDate ?? Date()) : nil,
                                isSettingDueDate ? remind : false,

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
            .navigationTitle(checklist == nil ? "New Checklist" : "Edit Checklist")
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
            Text("Please enter a title for your checklist.")
        }
        .onAppear {
            print("DEBUG: AddSimpleChecklistView appeared. Checklist: \(String(describing: checklist?.title)), ID: \(String(describing: checklist?.id))")
            if let checklist {
                print("DEBUG: Loading existing SimpleChecklist: \(checklist.title)")
                title = checklist.title
                notes = checklist.notes ?? ""
                dueDate = checklist.dueDate
                remind = checklist.remind
                isSettingDueDate = checklist.dueDate != nil
                selectedTags = checklist.tags
                recurrenceRule = checklist.recurrenceRule
            } else {
                // Explicitly reset ALL state for new tasks
                title = ""
                notes = ""
                dueDate = nil
                remind = true
                isSettingDueDate = false
                isSettingDueDate = false
                selectedTags = []
                recurrenceRule = nil
            }
        }
    }
}

struct SimpleChecklistRow: View {
    let checklist: SimpleChecklist
    let theme: Theme
    var isPendingCompletion: Bool // New Prop
    var onToggleDone: () -> Void
    var onEdit: () -> Void = {}
    
    // Removed local state to allow Parent-driven "Batch" logic

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox Button
            Button {
                onToggleDone()
            } label: {
                Image(systemName: (checklist.isDone || isPendingCompletion) ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle((checklist.isDone || isPendingCompletion) ? theme.accent : .gray)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: isPendingCompletion)
            }
            .buttonStyle(.plain)
            .disabled(isPendingCompletion) // Prevent double-taps while pending

            VStack(alignment: .leading, spacing: 4) {
                Text(checklist.title)
                    .font(.headline)
                    .foregroundStyle((checklist.isDone || isPendingCompletion) ? .secondary : theme.primary)
                    .strikethrough((checklist.isDone || isPendingCompletion), color: .secondary)
                    .animation(.default, value: isPendingCompletion)
                    .lineLimit(2) // Allow wrapping
                
                // Multi-Tag Display
                if !checklist.tags.isEmpty {
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
                }
                if let notes = checklist.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let dueDate = checklist.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text(timeRemaining(until: dueDate))
                            .font(.caption)
                            .accessibilityIdentifier("timeRemainingLabel_\(checklist.title)")
                    }
                    .foregroundStyle(deadlineColor(for: dueDate))
                }
            }
            Spacer()
            
            // Edit button
            Button {
                onEdit()
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.plain)
        }
        .accessibilityIdentifier("checklistRow_\(checklist.title)")
        .padding()
        .background(
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
        )
        .shadow(color: checklist.isStarred ? theme.accent.opacity(0.25) : .black.opacity(0.05), radius: checklist.isStarred ? 8 : 5, x: 0, y: 2)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: checklist.isStarred)
        .transition(.opacity.combined(with: .move(edge: .trailing)))
        .animation(.easeInOut, value: checklist.isDone)
        .contextMenu {
            Button {
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button {
                onToggleDone()
            } label: {
                Label(checklist.isDone ? "Mark Undone" : "Mark Done", systemImage: checklist.isDone ? "circle" : "checkmark.circle")
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

#Preview {
    SimpleChecklistView(theme: .default)
        .modelContainer(for: [SimpleChecklist.self, Tag.self], inMemory: true)
}


private extension View {
    func isDarkColor(_ color: Color) -> Bool {
        return true 
    }
}
