import SwiftUI

// Shared Celebration Sheet
struct ThemeUnlockSheet: View {
    let theme: Theme // Current theme for styling
    let newTheme: Theme
    @Environment(\.dismiss) var dismiss
    @State private var showLoginSheet = false
    
    var body: some View {
        ZStack {
            newTheme.background.ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Icon / Art
                ZStack {
                    Circle()
                        .fill(newTheme.accent.opacity(0.15))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(newTheme.accent)
                        .symbolEffect(.bounce, options: .repeating)
                }
                .shadow(color: newTheme.accent.opacity(0.4), radius: 15)
                
                // Text
                VStack(spacing: 8) {
                    Text("New Theme Unlocked!")
                        .font(.title2.bold())
                        .foregroundStyle(newTheme.primary)
                    
                    Text("You've unlocked the \(newTheme.name) theme.")
                        .font(.body)
                        .foregroundStyle(newTheme.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Actions
                VStack(spacing: 12) {
                    Button {
                        if AuthManager.shared.isAuthenticated {
                            // Switch immediately
                            ThemeSelectionManager.shared.selectTheme(id: newTheme.id)
                            dismiss()
                        } else {
                            // Require Login
                            showLoginSheet = true
                        }
                    } label: {
                        Text("Use \(newTheme.name)")
                            .font(.headline)
                            .foregroundStyle(newTheme.isDark ? .black : .white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(newTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    
                    Button("Keep Current Theme") {
                        dismiss()
                    }
                    .font(.subheadline)
                    .foregroundStyle(newTheme.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .padding(.top, 40)
        }
        .sheet(isPresented: $showLoginSheet) {
            LoginView()
        }
    }
}
