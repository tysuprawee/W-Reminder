import SwiftUI
import SwiftData
import UserNotifications
import UIKit

struct SimpleChecklistView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SimpleChecklist.createdAt, order: .forward) private var checklists: [SimpleChecklist]

    @State private var showingAdd = false
    @State private var editing: SimpleChecklist?
    @State private var showPermissionAlert = false

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

                VStack(alignment: .leading, spacing: 16) {
                    header

                    let active = checklists.filter { !$0.isDone }

                    if active.isEmpty {
                        emptyState
                    } else {
                        list(active: active)
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Checklists")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline)
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddSimpleChecklistView(
                    checklist: editing,
                    theme: theme
                ) { title, notes, dueDate, remind in
                    save(
                        original: editing,
                        title: title,
                        notes: notes,
                        dueDate: dueDate,
                        remind: remind
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
                Text("Enable notifications in Settings to get checklist alerts.")
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
        remind: Bool
    ) {
        let checklist: SimpleChecklist
        if let original {
            checklist = original
            checklist.title = title
            checklist.notes = notes
            checklist.dueDate = dueDate
            checklist.remind = remind
        } else {
            checklist = SimpleChecklist(
                title: title,
                notes: notes,
                dueDate: dueDate,
                remind: remind
            )
            modelContext.insert(checklist)
        }

        NotificationManager.shared.cancelNotification(for: checklist)
        NotificationManager.shared.scheduleNotification(for: checklist)
        verifyNotificationPermission()
        editing = nil
    }

    private func delete(offsets: IndexSet, in source: [SimpleChecklist]) {
        withAnimation {
            for index in offsets {
                let checklist = source[index]
                NotificationManager.shared.cancelNotification(for: checklist)
                modelContext.delete(checklist)
            }
        }
    }

    private func list(active: [SimpleChecklist]) -> some View {
        List {
            ForEach(active) { checklist in
                SimpleChecklistRow(checklist: checklist, theme: theme) {
                    withAnimation(.easeInOut) {
                        checklist.isDone.toggle()
                    }
                    NotificationManager.shared.cancelNotification(for: checklist)
                } onEdit: {
                    editing = checklist
                    showingAdd = true
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
            .onDelete { offsets in
                delete(offsets: offsets, in: active)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Quick checklists")
                .font(.title2.bold())
            Text("Single-step tasks with optional reminders.")
                .foregroundStyle(theme.secondary)
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

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var dueDate: Date? = nil
    @State private var remind: Bool = true

    var checklist: SimpleChecklist?
    let theme: Theme
    var onSave: (String, String?, Date?, Bool) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Checklist")) {
                    TextField("Title", text: $title)
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(1...4)

                    Toggle("Notify me", isOn: $remind)

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
                            remind ? dueDate : nil,
                            remind
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
            }
        }
    }
}

struct SimpleChecklistRow: View {
    let checklist: SimpleChecklist
    let theme: Theme
    var onToggleDone: () -> Void
    var onEdit: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Button {
                withAnimation(.easeInOut) {
                    onToggleDone()
                }
            } label: {
                Image(systemName: checklist.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(checklist.isDone ? theme.accent : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(checklist.title)
                    .font(.headline)
                    .strikethrough(checklist.isDone, color: .secondary)
                if let notes = checklist.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let due = checklist.dueDate {
                    HStack(spacing: 6) {
                        Text(due, format: .dateTime.day().month().hour().minute())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(timeRemaining(until: due))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Button {
                onEdit()
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(theme.background.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .transition(.opacity.combined(with: .move(edge: .trailing)))
        .animation(.easeInOut, value: checklist.isDone)
    }

    private func timeRemaining(until date: Date) -> String {
        let remaining = date.timeIntervalSinceNow
        if remaining <= 0 {
            return "Overdue"
        }
        let hours = remaining / 3600
        if hours >= 24 {
            let days = Int(hours / 24)
            return "\(days) day\(days == 1 ? "" : "s") left"
        } else {
            let h = Int(ceil(hours))
            return "\(h) hour\(h == 1 ? "" : "s") left"
        }
    }
}

#Preview {
    SimpleChecklistView(theme: .default)
        .modelContainer(for: [SimpleChecklist.self], inMemory: true)
}

