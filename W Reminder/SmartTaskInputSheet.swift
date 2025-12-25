//
//  SmartTaskInputSheet.swift
//  W Reminder
//
//  Created by W Reminder App on 12/25/24.
//

import SwiftUI

struct SmartTaskInputSheet: View {
    let theme: Theme
    var onCommit: (String, String?, Date?, String?) -> Void // Added Recurrence
    @Environment(\.dismiss) private var dismiss
    
    @State private var text: String = ""
    @FocusState private var isFocused: Bool
    
    @State private var parsedDate: Date?
    @State private var parsedTitle: String = ""
    @State private var parsedNotes: String? = nil
    @State private var parsedRecurrence: String? = nil // New State
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("What's on your mind?")
                    .font(.headline)
                    .foregroundStyle(theme.primary)
                Spacer()
                
                // Create Button (Always reserves space to prevent layout jump)
                Button("Create") {
                    let finalTitle = parsedTitle.isEmpty ? text : parsedTitle
                    onCommit(finalTitle, parsedNotes, parsedDate, parsedRecurrence)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)
                .clipShape(Capsule())
                .disabled(text.isEmpty)
                .opacity(text.isEmpty ? 0 : 1)
                .animation(.easeInOut, value: text.isEmpty)
            }
            .padding(.top)
            
            // Text Input
            TextField("e.g. Call Mom tomorrow at 5pm...", text: $text, axis: .vertical)
                .font(.title3)
                .lineLimit(2...4)
                .focused($isFocused)
                .onChange(of: text) { _,  newValue in
                    // Live Parse
                    let result = SmartTaskParser.parse(text: newValue)
                    withAnimation {
                        parsedTitle = result.title
                        parsedNotes = result.notes
                        parsedDate = result.dueDate
                        parsedRecurrence = result.recurrenceRule
                    }
                }
            
            // Preview / Feedback Area
            // Logic: Show preview if we have a Date OR a Recurrence (which implies Today)
            let displayDate = parsedDate ?? (parsedRecurrence != nil ? Date() : nil)
            
            if let date = displayDate {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundStyle(theme.accent)
                        .padding(.top, 2)
                    
                VStack(alignment: .leading, spacing: 4) {
                        // Title Summary
                        Text(parsedTitle.isEmpty ? (text.isEmpty ? "New Task" : text) : parsedTitle)
                            .font(.headline)
                            .foregroundStyle(theme.primary)
                            .lineLimit(2)
                        
                        // Date + Recurrence
                        HStack(spacing: 4) {
                            Text(date.formatted(date: .omitted, time: .shortened) + ", " + date.formatted(date: .abbreviated, time: .omitted))
                            
                            if let rule = parsedRecurrence {
                                Text("• \(rule.capitalized)")
                                    .fontWeight(.bold)
                                    .foregroundStyle(theme.accent)
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(theme.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.accent.opacity(0.1))
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                 Spacer().frame(height: 30) // Placeholder
            }
            
            Spacer()
        }
        .padding()
        .background(theme.background.ignoresSafeArea())
        .onAppear {
            isFocused = true
        }
    }
}
