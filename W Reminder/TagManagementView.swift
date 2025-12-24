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
                TagEditView(theme: theme) { name, color, isTextWhite in
                    let hexString = color.toHex()
                    let newTag = Tag(name: name, colorHex: hexString, isTextWhite: isTextWhite)
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
                TagEditView(tag: tag, theme: theme) { name, color, isTextWhite in
                    tag.name = name
                    tag.colorHex = color.toHex()
                    tag.isTextWhite = isTextWhite
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
    let onSave: (String, Color, Bool) -> Void
    
    @State private var name: String
    @State private var selectedColor: Color
    @State private var isTextWhite: Bool
    @Environment(\.dismiss) private var dismiss
    
    init(tag: Tag? = nil, theme: Theme, onSave: @escaping (String, Color, Bool) -> Void) {
        self.tag = tag
        self.theme = theme
        self.onSave = onSave
        _name = State(initialValue: tag?.name ?? "")
        _selectedColor = State(initialValue: tag?.color ?? .blue)
        _isTextWhite = State(initialValue: tag?.isTextWhite ?? true)
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
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
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
                
                // Text Color Preference
                // Text Color Preference
                HStack {
                    Text("Text Color")
                    Spacer()
                    
                    // Black Text Option
                    Button {
                        isTextWhite = false
                    } label: {
                        Text("Abc")
                            .font(.caption.bold())
                            .foregroundStyle(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedColor)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(!isTextWhite ? theme.accent : Color.clear, lineWidth: !isTextWhite ? 3 : 0)
                            )
                            .overlay(
                                // Inner border for unselected state to show boundary clearly if needed
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                            .scaleEffect(!isTextWhite ? 1.1 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isTextWhite)
                    }
                    .buttonStyle(.plain)
                    
                    // White Text Option
                    Button {
                        isTextWhite = true
                    } label: {
                        Text("Abc")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedColor)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isTextWhite ? theme.accent : Color.clear, lineWidth: isTextWhite ? 3 : 0)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                            .scaleEffect(isTextWhite ? 1.1 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isTextWhite)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
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
                    onSave(name, selectedColor, isTextWhite)
                }
                .disabled(name.isEmpty)
            }
        }
    }
    
    private var colorPresets: [Color] {
        [
            Color(hex: "#D32F2F"), // Red
            Color(hex: "#EF5350"), // Light Red
            Color(hex: "#AB47BC"), // Purple
            Color(hex: "#7E57C2"), // Deep Purple
            Color(hex: "#5C6BC0"), // Indigo
            Color(hex: "#42A5F5"), // Blue
            Color(hex: "#29B6F6"), // Light Blue
            Color(hex: "#26C6DA"), // Cyan
            Color(hex: "#26A69A"), // Teal
            Color(hex: "#66BB6A"), // Green
            Color(hex: "#9CCC65"), // Light Green
            Color(hex: "#D4E157"), // Lime
            Color(hex: "#FFEE58"), // Yellow (Darker)
            Color(hex: "#FFCA28"), // Amber
            Color(hex: "#FFA726"), // Orange
            Color(hex: "#FF7043"), // Deep Orange
            Color(hex: "#8D6E63"), // Brown
            Color(hex: "#78909C")  // Blue Grey
        ]
    }
}

