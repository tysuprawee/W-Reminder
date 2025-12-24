//
//  TagManagementView.swift
//  W Reminder
//

import SwiftUI
import SwiftData
import UIKit

struct TagManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tags: [Tag]
    
    let theme: Theme
    
    @State private var showingAddTag = false
    @State private var editingTag: Tag?
    
    var body: some View {
        List {
            if tags.isEmpty {
                ContentUnavailableView(
                    "No Tags",
                    systemImage: "tag.slash",
                    description: Text("Tap + to create your first tag")
                )
            } else {
                ForEach(tags) { tag in
                    Button {
                        editingTag = tag
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(tag.color)
                                .frame(width: 24, height: 24)
                            
                            Text(tag.name)
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: deleteTags)
            }
        }
        .navigationTitle("Manage Tags")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddTag = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddTag) {
            NavigationStack {
                TagEditView(theme: theme) { name, color in
                    let hexString = color.toHex()
                    let newTag = Tag(name: name, colorHex: hexString)
                    modelContext.insert(newTag)
                    try? modelContext.save()
                    Task {
                        await SyncManager.shared.sync(container: modelContext.container, silent: true)
                    }
                    showingAddTag = false
                }
            }
        }
        .sheet(item: $editingTag) { tag in
            NavigationStack {
                TagEditView(tag: tag, theme: theme) { name, color in
                    tag.name = name
                    tag.colorHex = color.toHex()
                    try? modelContext.save()
                    Task {
                        await SyncManager.shared.sync(container: modelContext.container, silent: true)
                    }
                    editingTag = nil
                }
            }
        }
        .preferredColorScheme(theme.isDark ? .dark : .light)
    }
    
    private func deleteTags(at offsets: IndexSet) {
        for index in offsets {
            let tag = tags[index]
            // Register deletion for sync
            SyncManager.shared.registerDeletion(of: tag, context: modelContext)
            modelContext.delete(tag)
        }

        try? modelContext.save()
        Task {
            await SyncManager.shared.sync(container: modelContext.container, silent: true)
        }
    }
}

struct TagEditView: View {
    let tag: Tag?
    let theme: Theme
    let onSave: (String, Color) -> Void
    
    @State private var name: String
    @State private var selectedColor: Color
    @Environment(\.dismiss) private var dismiss
    
    init(tag: Tag? = nil, theme: Theme, onSave: @escaping (String, Color) -> Void) {
        self.tag = tag
        self.theme = theme
        self.onSave = onSave
        _name = State(initialValue: tag?.name ?? "")
        _selectedColor = State(initialValue: tag?.color ?? .blue)
    }
    
    var body: some View {
        Form {
            Section("Tag Details") {
                TextField("Tag Name", text: $name)
            }
            
            Section("Color") {
                ColorPicker("Select Color", selection: $selectedColor, supportsOpacity: false)
                
                // Color presets
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                    ForEach(colorPresets, id: \.self) { color in
                        Circle()
                            .fill(color)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle()
                                    .stroke(selectedColor == color ? theme.accent : Color.clear, lineWidth: 3)
                            )
                            .onTapGesture {
                                selectedColor = color
                            }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle(tag == nil ? "New Tag" : "Edit Tag")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(name, selectedColor)
                }
                .disabled(name.isEmpty)
            }
        }
    }
    
    private var colorPresets: [Color] {
        [
            Color(red: 1.0, green: 0.70, blue: 0.73), // Pastel Red
            Color(red: 1.0, green: 0.87, blue: 0.73), // Pastel Orange
            Color(red: 1.0, green: 1.0, blue: 0.73), // Pastel Yellow
            Color(red: 0.73, green: 1.0, blue: 0.79), // Pastel Green
            Color(red: 0.73, green: 0.88, blue: 1.0), // Pastel Blue
            Color(red: 0.85, green: 0.75, blue: 0.90), // Pastel Purple
            Color(red: 1.0, green: 0.80, blue: 0.85), // Pastel Pink
            Color(red: 0.67, green: 0.94, blue: 0.82), // Pastel Teal
            Color(red: 0.87, green: 0.94, blue: 0.95), // Pastel Cyan
            Color(red: 0.95, green: 0.85, blue: 0.70), // Pastel Beige
            Color(red: 0.80, green: 0.75, blue: 0.70), // Pastel Brown
            Color(red: 0.85, green: 0.85, blue: 0.85)  // Pastel Gray
        ]
    }
}

