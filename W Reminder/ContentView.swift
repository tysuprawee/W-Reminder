//
//  ContentView.swift
//  W Reminder
//
//  Created by Suprawee Pongpeeradech on 11/20/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Reminder.dueDate, order: .forward) private var reminders: [Reminder]

    @State private var showingAddReminder = false

    var body: some View {
        NavigationStack {
            List {
                if reminders.isEmpty {
                    Text("No reminders yet.\nTap + to add one.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(reminders) { reminder in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(reminder.title)
                                .font(.headline)

                            Text(reminder.dueDate, format: .dateTime
                                .hour().minute().day().month().year())
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            if let notes = reminder.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteReminders)
                }
            }
            .navigationTitle("W Reminder")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddReminder = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddReminder) {
                AddReminderView { title, dueDate, notes in
                    addReminder(title: title, dueDate: dueDate, notes: notes)
                }
            }
        }
    }

    private func addReminder(title: String, dueDate: Date, notes: String?) {
        let newReminder = Reminder(title: title, dueDate: dueDate, notes: notes)
        modelContext.insert(newReminder)
        NotificationManager.shared.scheduleNotification(for: newReminder)
    }

    private func deleteReminders(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let reminder = reminders[index]
                NotificationManager.shared.cancelNotification(for: reminder)
                modelContext.delete(reminder)
            }
        }
    }
}

struct AddReminderView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var dueDate: Date = Date().addingTimeInterval(3600) // default 1h from now

    var onSave: (String, Date, String?) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Reminder")) {
                    TextField("Title", text: $title)
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(1...4)

                    DatePicker("Date & Time", selection: $dueDate)
                }
            }
            .navigationTitle("New Reminder")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else {
                            return
                        }
                        onSave(title, dueDate, notes.isEmpty ? nil : notes)
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Reminder.self, inMemory: true)
}
