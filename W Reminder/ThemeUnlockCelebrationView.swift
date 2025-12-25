//
//  ThemeUnlockCelebrationView.swift
//  W Reminder
//
//  Display popup when a theme is unlocked
//

import SwiftUI

struct ThemeUnlockCelebrationView: View {
    let theme: Theme
    var onDismiss: () -> Void
    var onApply: () -> Void
    
    @State private var animate = false
    
    var body: some View {
        ZStack {
            // Dim background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }
            
            VStack(spacing: 20) {
                // Header / Icon
                ZStack {
                    Circle()
                        .fill(theme.background)
                        .frame(width: 100, height: 100)
                        .shadow(color: theme.accent.opacity(0.5), radius: 10, x: 0, y: 0)
                    
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(theme.accent)
                }
                .scaleEffect(animate ? 1.0 : 0.5)
                .opacity(animate ? 1.0 : 0.0)
                
                VStack(spacing: 8) {
                    Text("New Theme Unlocked!")
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                    
                    Text(theme.name)
                        .font(.title3)
                        .foregroundStyle(theme.primary)
                    
                    Text("You've met the requirements to use this theme.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
                
                HStack(spacing: 16) {
                    Button("Later") {
                        onDismiss()
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                    
                    Button("Apply Now") {
                        onApply()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.accent)
                }
                .padding(.top, 10)
            }
            .padding(30)
            .background(Color(UIColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(radius: 20)
            .padding(.horizontal, 40)
            .scaleEffect(animate ? 1.0 : 0.8)
            .opacity(animate ? 1.0 : 0.0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                animate = true
            }
        }
    }
}
