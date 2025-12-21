import SwiftUI
import SwiftData
import UserNotifications
import WidgetKit
import UIKit

struct MilestoneDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Bindable Checklist to observe updates
    @Bindable var checklist: Checklist
    let theme: Theme
    
    // States
    @State private var showingEditSheet = false
    @State private var isConfettiActive = false
    @State private var completionTask: Task<Void, Error>? = nil
    @State private var itemToEditDate: ChecklistItem?
    @State private var newTaskText: String = ""
    @FocusState private var isInputFocused: Bool
    
    // XP Constants
    private let xpPerSubTask = 5
    private let xpCompletionBonus = 50
    
    // Progress Calculation
    var progress: Double {
        let total = checklist.items.count
        guard total > 0 else { return 0 }
        let done = checklist.items.filter { $0.isDone }.count
        return Double(done) / Double(total)
    }
    
    var completedCount: Int {
        checklist.items.filter { $0.isDone }.count
    }
    
    var totalCount: Int {
        checklist.items.count
    }
    
    var body: some View {
        ZStack {
            // Background
            theme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Header
                headerView
                
                // MARK: - Task List
                // We use List to support swipe-to-delete and reorder
                List {
                    let sortedItems = checklist.items.sorted { $0.position < $1.position }
                    
                    ForEach(sortedItems) { item in
                        MilestoneTaskRow(item: item, theme: theme, onToggle: {
                            toggleItem(item)
                        }, onSetDate: {
                            itemToEditDate = item
                        })
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteItem(item)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            
                            Button {
                                itemToEditDate = item
                            } label: {
                                Label("Date", systemImage: "calendar")
                            }
                            .tint(.orange)
                        }
                    }
                    .onMove(perform: moveItems)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.defaultMinListRowHeight, 50)
                
                // MARK: - Quick Add
                VStack(spacing: 0) {
                    Divider().background(theme.secondary.opacity(0.3))
                    
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(theme.secondary)
                        
                        TextField("Add a task...", text: $newTaskText)
                            .submitLabel(.done)
                            .focused($isInputFocused)
                            .onSubmit {
                                addNewTask()
                            }
                            .foregroundStyle(theme.primary)
                        
                        if !newTaskText.isEmpty {
                            Button {
                                addNewTask()
                            } label: {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(theme.accent)
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                }
                
                // Space for Bottom Bar
                if !isInputFocused {
                    bottomBar
                        .padding(.top, -8) // Tighten spacing
                }
            }
            
            // Confetti Overlay
            if isConfettiActive {
               GamificationOverlay()
                    .allowsHitTesting(false)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
             ToolbarItem(placement: .topBarLeading) {
                 Button {
                     dismiss()
                 } label: {
                     Image(systemName: "chevron.left")
                         .font(.headline)
                         .foregroundStyle(theme.primary)
                         .frame(width: 40, height: 40)
                         .background(.ultraThinMaterial)
                         .clipShape(Circle())
                 }
             }
             
             ToolbarItem(placement: .topBarTrailing) {
                 HStack {
                     EditButton()
                        .foregroundStyle(theme.primary)
                     
                     Button {
                         showingEditSheet = true
                     } label: {
                         Image(systemName: "gearshape") // Changed to Gear since it's now Settings
                             .font(.headline)
                             .foregroundStyle(theme.primary)
                             .frame(width: 40, height: 40)
                             .background(.ultraThinMaterial)
                             .clipShape(Circle())
                     }
                 }
             }
        }
        .sheet(isPresented: $showingEditSheet) {
            AddChecklistView(
                checklist: checklist,
                theme: theme
            ) { title, notes, dueDate, remind, items, isDone, tags, recurrenceRule in
                updateChecklist(title: title, notes: notes, dueDate: dueDate, remind: remind, items: items, isDone: isDone, tags: tags, recurrenceRule: recurrenceRule)
            }
        }
        .sheet(item: $itemToEditDate) { item in
            ItemDateEditView(item: item, theme: theme) {
                // Save triggered
                try? modelContext.save()
                WidgetCenter.shared.reloadAllTimelines()
                itemToEditDate = nil
            }
            .presentationDetents([.height(300)])
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        VStack(spacing: 16) {
            // Progress Ring & Title
            HStack(spacing: 20) {
                 ZStack {
                     // Background Ring
                     Circle()
                         .stroke(theme.secondary.opacity(0.2), lineWidth: 10)
                         .frame(width: 80, height: 80)
                     
                     // Progress Ring
                     Circle()
                         .trim(from: 0, to: progress)
                         .stroke(
                            AngularGradient(colors: [theme.accent, theme.primary], center: .center),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                         )
                         .rotationEffect(.degrees(-90))
                         .frame(width: 80, height: 80)
                         .animation(.spring(response: 0.6, dampingFraction: 0.7), value: progress)
                     
                     // Percentage Text
                     Text("\(Int(progress * 100))%")
                         .font(.caption.bold())
                         .foregroundStyle(theme.primary)
                 }
                 
                 VStack(alignment: .leading, spacing: 4) {
                     Text(checklist.title)
                         .font(.title2.bold())
                         .foregroundStyle(theme.primary)
                         .lineLimit(2)
                     
                     if let notes = checklist.notes, !notes.isEmpty {
                         Text(notes)
                             .font(.subheadline)
                             .foregroundStyle(theme.secondary)
                             .lineLimit(2)
                     }
                     
                     HStack(spacing: 6) {
                         Image(systemName: "list.bullet.clipboard")
                             .font(.caption)
                         Text("\(completedCount)/\(totalCount) Tasks")
                             .font(.caption.bold())
                         
                         if let dueDate = checklist.dueDate {
                             Text("•")
                             Text(dueDate.formatted(date: .abbreviated, time: .shortened))
                                 .font(.caption)
                         }
                     }
                     .foregroundStyle(theme.secondary)
                 }
                 Spacer()
            }
            .padding(.horizontal)
            .padding(.top)
        }
        .padding(.bottom)
        .background(.ultraThinMaterial)
    }
    
    private var bottomBar: some View {
         HStack {
             if checklist.isDone {
                 Button {
                      completeMilestone(false)
                 } label: {
                      Label("Mark Undone", systemImage: "arrow.uturn.backward")
                          .font(.headline)
                          .foregroundStyle(theme.secondary)
                          .frame(maxWidth: .infinity)
                          .frame(height: 56)
                          .background(.ultraThinMaterial)
                          .clipShape(RoundedRectangle(cornerRadius: 20))
                 }
                 .transition(.move(edge: .bottom).combined(with: .opacity))
             } else if progress == 1.0 {
                 Button {
                      completeMilestone(true)
                 } label: {
                      Text("Complete Milestone")
                          .font(.headline)
                          .foregroundStyle(.white)
                          .frame(maxWidth: .infinity)
                          .frame(height: 56)
                          .background(
                              LinearGradient(colors: [theme.accent, theme.primary], startPoint: .leading, endPoint: .trailing)
                          )
                          .clipShape(RoundedRectangle(cornerRadius: 20))
                          .shadow(color: theme.accent.opacity(0.3), radius: 10, y: 5)
                 }
                 .transition(.move(edge: .bottom).combined(with: .opacity))
             }
         }
         .padding()
         .animation(.spring, value: checklist.isDone)
         .animation(.spring, value: progress)
         .disabled(isConfettiActive) // Prevent accidental double-tap (completing then un-completing)
    }
    
    // MARK: - Logic
    
    private func addNewTask() {
        guard !newTaskText.isEmpty else { return }
        
        let position = checklist.items.count
        let newItem = ChecklistItem(text: newTaskText, isDone: false, position: position)
        newItem.checklist = checklist
        checklist.items.append(newItem)
        
        newTaskText = ""
        // Adding a task decreases progress, so if we were done, we might need to un-complete?
        // If milestone was Done (100%), adding a task makes it 99% (Not Done).
        // Robustness: Auto-uncheck milestone if new task added?
        if checklist.isDone {
            checklist.isDone = false
            LevelManager.shared.addExp(-xpCompletionBonus)
        }
        
        saveChanges()
    }
    
    private func deleteItem(_ item: ChecklistItem) {
        if let idx = checklist.items.firstIndex(of: item) {
             checklist.items.remove(at: idx)
        }
        modelContext.delete(item)
        // Deleting a task might achieve 100%. User must manually click complete though.
        saveChanges()
    }
    
    private func moveItems(from source: IndexSet, to destination: Int) {
        var items = checklist.items.sorted { $0.position < $1.position }
        items.move(fromOffsets: source, toOffset: destination)
        
        // Update positions
        for (index, item) in items.enumerated() {
            item.position = index
        }
        // Force update relationship order implies needing to save
        // SwiftData doesn't strictly support ordered relationships natively without sorting by a property
        saveChanges()
    }
    
    private func saveChanges() {
         try? modelContext.save()
         WidgetCenter.shared.reloadAllTimelines()
         Task { await SyncManager.shared.sync(container: modelContext.container, silent: true) }
    }
    
    // Toggles a sub-task and awards/deducts "Mini XP"
    private func toggleItem(_ item: ChecklistItem) {
        let targetState = !item.isDone
        
        // 1. Optimistic UI
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
             item.isDone = targetState
        }
        
        // Auto-Demote: If we uncheck a task, the Milestone cannot be Done anymore.
        if !targetState && checklist.isDone {
            checklist.isDone = false
            LevelManager.shared.addExp(-xpCompletionBonus) // Revoke bonus
            // Haptic for demotion?
        }
        
        // 2. Transactional Save
        do {
            try modelContext.save()
            
            // 3. XP Logic (Add or Deduct)
            if targetState {
                // Completed: Add XP
                LevelManager.shared.addExp(xpPerSubTask)
                // Haptic
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            } else {
                // Unchecked: Deduct XP (Prevent farming)
                LevelManager.shared.addExp(-xpPerSubTask)
            }
            
            WidgetCenter.shared.reloadAllTimelines()
             Task {
                 await SyncManager.shared.sync(container: modelContext.container, silent: true)
             }
             
        } catch {
             // Rollback
             withAnimation {
                 item.isDone = !targetState
             }
             print("Failed to save item toggle: \(error)")
        }
    }
    
    // Toggles the entire Milestone and awards "Bonus XP"
    private func completeMilestone(_ isDone: Bool) {
        if isDone {
             // 1. Start Celebration (Model NOT updated yet to prevent premature view pop)
             isConfettiActive = true
             
             // Haptics
             let generator = UINotificationFeedbackGenerator()
             generator.notificationOccurred(.success)
             
             // 2. Bonus XP (Optimistic)
             LevelManager.shared.addExp(xpCompletionBonus)
             StreakManager.shared.incrementStreak()
             
             // 3. Delayed Persistence & Exit
             DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                 // Handle Recurrence (Spawn Next Milestone)
                 if let rule = checklist.recurrenceRule, !rule.isEmpty {
                     handleRecurrence(rule: rule)
                 }
                 
                 // NOW update the model
                 checklist.isDone = true
                 try? modelContext.save()
                 WidgetCenter.shared.reloadAllTimelines()
                 Task { await SyncManager.shared.sync(container: modelContext.container, silent: true) }
                 
                 dismiss()
             }
        } else {
             // Mark Undone (Immediate)
             checklist.isDone = false
             // If we mark undone, and it HAD a recurrence rule that we cleared... we can't restore it easily unless we stored it elsewhere.
             // Limitation: "Resurrecting" a recurring milestone kills the recurrence chain if we already spawned the new one.
             // But usually you mark undone to fix a mistake instantly.
             // If we wait 2 seconds, we spawn the new one.
             // If user marks undone *after* 2 seconds (from the archive list), the new one already exists.
             // It's acceptable.
             
             LevelManager.shared.addExp(-xpCompletionBonus)
             
             try? modelContext.save()
             WidgetCenter.shared.reloadAllTimelines()
             Task { await SyncManager.shared.sync(container: modelContext.container, silent: true) }
             
             // No dismiss, let user edit
        }
    }
    
    private func handleRecurrence(rule: String) {
        let baseDate = checklist.dueDate ?? Date()
        guard let nextDate = RecurrenceHelper.calculateNextDueDate(from: baseDate, rule: rule) else { return }
        
        // Calculate Time Delta for sub-tasks
        let delta = nextDate.timeIntervalSince(baseDate)
        
        // Create new items (Deep Copy)
        var newItems: [ChecklistItem] = []
        for item in checklist.items.sorted(by: { $0.position < $1.position }) {
            var newItemDate: Date? = nil
            if let oldDate = item.dueDate {
                newItemDate = oldDate.addingTimeInterval(delta)
            }
            
            let newItem = ChecklistItem(
                text: item.text,
                isDone: false, // Reset state
                position: item.position,
                dueDate: newItemDate
            )
            newItems.append(newItem)
        }
        
        // Create new Milestone
        let newChecklist = Checklist(
            title: checklist.title,
            notes: checklist.notes,
            dueDate: nextDate,
            remind: checklist.remind,
            items: newItems,
            tags: checklist.tags, // Maintain tags
            isStarred: checklist.isStarred,
            recurrenceRule: rule // Pass the torch
        )
        
        // Explicitly link items (SwiftData requires this often)
        for item in newItems { item.checklist = newChecklist }
        
        modelContext.insert(newChecklist)
        
        // Remove recurrence from the completed one so it doesn't trigger again
        checklist.recurrenceRule = nil
    }
    
    // Update logic from Edit Sheet
    private func updateChecklist(title: String, notes: String?, dueDate: Date?, remind: Bool, items: [ChecklistItem], isDone: Bool, tags: [Tag], recurrenceRule: String?) {
        checklist.title = title
        checklist.notes = notes
        checklist.dueDate = dueDate
        checklist.remind = remind
        checklist.tags = tags
        checklist.recurrenceRule = recurrenceRule
        checklist.isDone = isDone // If they toggle done in edit sheet
        
        // Sync Items Logic (Clone & Replace safely)
        for old in checklist.items { 
            modelContext.delete(old) 
        }
        
        let newItems = items.enumerated().map { idx, item -> ChecklistItem in
             let fresh = ChecklistItem(text: item.text, isDone: item.isDone, position: idx, dueDate: item.dueDate)
             fresh.checklist = checklist
             return fresh
        }
        checklist.items = newItems
        
        try? modelContext.save()
        WidgetCenter.shared.reloadAllTimelines()
        Task {
            await SyncManager.shared.sync(container: modelContext.container, silent: true)
        }
        
        showingEditSheet = false
    }
}

// MARK: - Row View
struct MilestoneTaskRow: View {
    @Bindable var item: ChecklistItem
    let theme: Theme
    var onToggle: () -> Void
    var onSetDate: () -> Void
    
    var timeRemaining: String? {
        guard let date = item.dueDate else { return nil }
        // Simple relative formatter
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func colorForDeadline(_ date: Date) -> Color {
        if date < Date() { return .red }
        if date < Date().addingTimeInterval(3600*24) { return .orange }
        return .secondary
    }
    
    var body: some View {
        Button {
            onToggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isDone ? theme.accent : theme.secondary)
                    .contentTransition(.symbolEffect(.replace))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.text)
                        .font(.body)
                        .strikethrough(item.isDone, color: .secondary)
                        .foregroundStyle(item.isDone ? .secondary : theme.primary)
                    
                    if let remaining = timeRemaining, let due = item.dueDate {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                            Text(remaining)
                        }
                        .font(.caption2)
                        .foregroundStyle(colorForDeadline(due))
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(theme.background) // Or a card color
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(theme.primary.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
            .contentShape(Rectangle())
            .contextMenu {
                 Button {
                     onSetDate()
                 } label: {
                     Label(item.dueDate == nil ? "Set Deadline" : "Change Deadline", systemImage: "calendar")
                 }
            }
        }
        .buttonStyle(.plain)
    }
}


struct ItemDateEditView: View {
    @Bindable var item: ChecklistItem
    let theme: Theme
    var onSave: () -> Void
    @Environment(\.dismiss) var dismiss
    
    // Local state to handle changes before save
    @State private var selectedDate: Date = Date()
    @State private var hasDate: Bool = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Set Due Date", isOn: $hasDate.animation())
                        .tint(theme.accent)
                    
                    if hasDate {
                        DatePicker("Date & Time", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                    }
                } footer: {
                    Text("Tasks with deadlines will be highlighted when due.")
                }
            }
            .navigationTitle("Set Deadline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                 ToolbarItem(placement: .confirmationAction) {
                     Button("Done") {
                         item.dueDate = hasDate ? selectedDate : nil
                         onSave()
                         dismiss()
                     }
                 }
                 ToolbarItem(placement: .cancellationAction) {
                     Button("Cancel") {
                         dismiss()
                     }
                 }
            }
            .onAppear {
                if let due = item.dueDate {
                    selectedDate = due
                    hasDate = true
                } else {
                    hasDate = false
                    selectedDate = Date().addingTimeInterval(3600) // Default to 1 hour later
                }
            }
        }
    }
}
