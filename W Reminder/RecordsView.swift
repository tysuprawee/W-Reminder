import SwiftUI
import SwiftData
import UserNotifications
import UIKit

struct RecordsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Checklist.createdAt, order: .reverse) private var milestones: [Checklist]
    @Query(sort: \SimpleChecklist.createdAt, order: .reverse) private var simples: [SimpleChecklist]

    enum RecordTab: String, CaseIterable, Identifiable {
        case milestones = "Milestones"
        case checklists = "Checklists"
        var id: String { rawValue }
    }

    @State private var selectedTab: RecordTab = .milestones
    @State private var editingMilestone: Checklist?
    @State private var editingSimple: SimpleChecklist?
    @State private var showMilestoneSheet = false
    @State private var showSimpleSheet = false
    @State private var confirmClearMilestones = false
    @State private var confirmClearSimples = false

    let theme: Theme

    private var completedMilestones: [Checklist] {
        milestones.filter { $0.isDone }
    }

    private var completedSimples: [SimpleChecklist] {
        simples.filter { $0.isDone }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundView

                VStack(alignment: .leading, spacing: 16) {
                    header
                    mainContent
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Records")
            .toolbar { toolbarContent }
            .sheet(item: $editingMilestone) { checklist in
                AddChecklistView(checklist: checklist, theme: theme) { title, notes, dueDate, remind, items, isDone, tags, recurrenceRule in
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
                AddSimpleChecklistView(checklist: checklist, theme: theme) { title, notes, dueDate, remind, tags, recurrenceRule in
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
            .alert("Clear milestone records?", isPresented: $confirmClearMilestones) {
                Button("Delete", role: .destructive) {
                    clearMilestones()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes all completed milestones.")
            }
            .alert("Clear checklist records?", isPresented: $confirmClearSimples) {
                Button("Delete", role: .destructive) {
                    clearSimples()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes all completed checklists.")
            }
        }
        .tint(theme.accent)
        .background(theme.background.ignoresSafeArea())
    }

    // MARK: - Subviews

    private var backgroundView: some View {
        LinearGradient(
            colors: [
                theme.background.opacity(0.9),
                theme.primary.opacity(0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var mainContent: some View {
        if completedMilestones.isEmpty && completedSimples.isEmpty {
            emptyState
        } else {
            segmentedControl
            listContent
        }
    }

    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if selectedTab == .milestones, !completedMilestones.isEmpty {
                Button("Clear Milestones") { confirmClearMilestones = true }
            }
            if selectedTab == .checklists, !completedSimples.isEmpty {
                Button("Clear Checklists") { confirmClearSimples = true }
            }
        }
    }

    private var milestoneSheetContent: some View {
        AddChecklistView(checklist: editingMilestone, theme: theme) { title, notes, dueDate, remind, items, isDone, tags, recurrenceRule in
            saveMilestone(
                original: editingMilestone,
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
        .id(editingMilestone?.id)
    }

    private var simpleSheetContent: some View {
        AddSimpleChecklistView(checklist: editingSimple, theme: theme) { title, notes, dueDate, remind, tags, recurrenceRule in
            saveSimple(
                original: editingSimple,
                title: title,
                notes: notes,
                dueDate: dueDate,
                remind: remind,
                tags: tags,
                recurrenceRule: recurrenceRule
            )
        }
        .id(editingSimple?.id)
    }

    // MARK: - Content

    private var segmentedControl: some View {
        Picker("Type", selection: $selectedTab) {
            ForEach(RecordTab.allCases) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }

    private var listContent: some View {
        List {
            if selectedTab == .milestones {
                Section("Milestone Records") {
                    ForEach(completedMilestones) { checklist in
                        ChecklistRow(
                            checklist: checklist,
                            theme: theme,
                            onEdit: {
                                editingMilestone = checklist
                            }
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
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
                        deleteMilestones(offsets: offsets)
                    }
                }
            } else {
                Section("Checklist Records") {
                    ForEach(completedSimples) { checklist in
                        SimpleChecklistRow(
                            checklist: checklist,
                            theme: theme,
                            isPendingCompletion: false,
                            onToggleDone: {
                                withAnimation(.easeInOut) {
                                    checklist.isDone.toggle()
                                }
                            },
                            onEdit: {
                                editingSimple = checklist
                            }
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
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
                        deleteSimples(offsets: offsets)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Completed items")
                .font(.title2.bold())
                .foregroundStyle(theme.primary)
            Text("Review, edit, or clear your finished milestones and checklists.")
                .foregroundStyle(theme.secondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 44))
                .foregroundStyle(theme.accent)
                .symbolRenderingMode(.multicolor)

            Text("No records yet")
                .font(.headline)
                .foregroundStyle(theme.primary)
            Text("Finish a milestone or checklist to see it here.")
                .foregroundStyle(theme.secondary)
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

        
        Task {
            await SyncManager.shared.sync(container: modelContext.container, silent: true)
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
                isDone: true,
                tags: tags,
                recurrenceRule: recurrenceRule
            )
            modelContext.insert(checklist)
        }

        NotificationManager.shared.cancelNotification(for: checklist)
        NotificationManager.shared.scheduleNotification(for: checklist)

        
        Task {
            await SyncManager.shared.sync(container: modelContext.container, silent: true)
        }
    }

    private func deleteMilestones(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let checklist = completedMilestones[index]
                NotificationManager.shared.cancelNotification(for: checklist)
                SyncManager.shared.registerDeletion(of: checklist, context: modelContext)
                modelContext.delete(checklist)
            }
        }
        try? modelContext.save()
        Task {
            await SyncManager.shared.sync(container: modelContext.container, silent: true)
        }
    }

    private func deleteSimples(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let checklist = completedSimples[index]
                NotificationManager.shared.cancelNotification(for: checklist)
                SyncManager.shared.registerDeletion(of: checklist, context: modelContext)
                modelContext.delete(checklist)
            }
        }
        try? modelContext.save()
        Task {
            await SyncManager.shared.sync(container: modelContext.container, silent: true)
        }
    }

    private func clearMilestones() {
        deleteMilestones(offsets: IndexSet(completedMilestones.indices))
        // deleteMilestones already calls sync
    }

    private func clearSimples() {
        for simple in completedSimples {
            SyncManager.shared.registerDeletion(of: simple, context: modelContext)
            modelContext.delete(simple)
        }
        try? modelContext.save()
        Task {
            await SyncManager.shared.sync(container: modelContext.container)
        }
    }
}

#Preview {
    RecordsView(theme: .default)
        .modelContainer(for: [Checklist.self, ChecklistItem.self, SimpleChecklist.self, Tag.self], inMemory: true)
}
