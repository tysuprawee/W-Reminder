//
//  LoginView.swift
//  W Reminder
//
//  Created for Cloud Sync
//

import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var showingAlert = false
    @State private var showingMergeAlert = false
    
    private let authManager = AuthManager.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom Nav Bar
                    HStack {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding()
                    
                    ScrollView {
                        VStack(spacing: 32) {
                            // Dynamic Header
                            VStack(spacing: 12) {
                                Image("Wreminder") // Use the new app logo
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .shadow(radius: 5)
                                
                                Text(isSignUp ? "Create Account" : "Welcome Back")
                                    .font(.system(size: 32, weight: .bold))
                                    .multilineTextAlignment(.center)
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                                
                                Text(isSignUp ? "Join us to sync your tasks across devices" : "Sign in to continue where you left off")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, 20)
                            
                            // Form Fields
                            VStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Email Address")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.leading, 4)
                                    
                                    TextField("name@example.com", text: $email)
                                        .textContentType(.emailAddress)
                                        .keyboardType(.emailAddress)
                                        .textInputAutocapitalization(.never)
                                        .padding()
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                                        )
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Password")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.leading, 4)
                                    
                                    SecureField("Password", text: $password)
                                        .textContentType(isSignUp ? .newPassword : .password)
                                        .padding()
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                                        )
                                }
                            }
                            .padding(.horizontal)
                            
                            // Action Buttons
                            VStack(spacing: 16) {
                                if authManager.isLoading {
                                    ProgressView()
                                        .frame(height: 50)
                                } else {
                                    Button {
                                        handleAuth()
                                    } label: {
                                        Text(isSignUp ? "Sign Up" : "Sign In")
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 50)
                                            .background(Color.accentColor)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .shadow(color: Color.accentColor.opacity(0.3), radius: 5, y: 3)
                                    }
                                    
                                    // Google Sign In
                                    Button {
                                        handleGoogleSignIn()
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image("google")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 24, height: 24)
                                            
                                            Text("Sign in with Google")
                                        }
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal)
                            
                            // Toggle Mode
                            Button {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                    isSignUp.toggle()
                                }
                            } label: {
                                HStack {
                                    Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                                        .foregroundStyle(.secondary)
                                    Text(isSignUp ? "Sign In" : "Sign Up")
                                        .bold()
                                        .foregroundStyle(Color.accentColor)
                                }
                                .font(.subheadline)
                            }
                            .padding(.bottom)
                        }
                    }
                }
            }
            .alert("Error", isPresented: Binding<Bool>(
                get: { authManager.errorMessage != nil },
                set: { _ in authManager.errorMessage = nil }
            )) {
                Button("OK") { authManager.errorMessage = nil }
            } message: {
                Text(authManager.errorMessage ?? "An unknown error occurred")
            }
            .alert("Success", isPresented: Binding<Bool>(
                get: { authManager.successMessage != nil },
                set: { _ in authManager.successMessage = nil }
            )) {
                Button("OK") { 
                    authManager.successMessage = nil
                }
            } message: {
                Text(authManager.successMessage ?? "")
            }
            .alert("Warning", isPresented: $showingMergeAlert) {
                Button("Delete Local Data & Sign In", role: .destructive) {
                    Task {
                        do {
                            // strictly enforce cloud state
                            try SyncManager.shared.deleteLocalData(context: modelContext)
                            LevelManager.shared.resetLocalData()
                            StreakManager.shared.resetLocalData()
                            
                            // Re-fetch profile to apply Cloud State (Fresh start)
                            await authManager.fetchProfile()
                            
                            await SyncManager.shared.sync(container: modelContext.container)
                            dismiss()
                        } catch {
                            print("Error clearing local data: \(error)")
                            dismiss()
                        }
                    }
                }
                Button("Cancel", role: .cancel) {
                    Task {
                        // User aborted the login because they want to keep local data
                        await authManager.signOut()
                        dismiss()
                    }
                }
            } message: {
                Text("Logging in will delete all local guest data (Tasks, Streak, XP). This action cannot be undone.")
            }
        }
    }
    
    private func handleAuth() {
        Task {
            do {
                if isSignUp {
                    try await authManager.signUp(email: email, password: password)
                    isSignUp = false
                } else {
                    try await authManager.signIn(email: email, password: password)
                    await checkMergeRequirements()
                }
            } catch {
                authManager.errorMessage = error.localizedDescription
                showingAlert = true
            }
        }
    }
    
    @MainActor
    private func checkMergeRequirements() async {
        // Ensure session is active before checking sync
        if !authManager.isAuthenticated {
            // Wait a brief moment for session to propagate if coming from redirect
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s check
            if !authManager.isAuthenticated {
                 // Still no session? Force initialize one last time
                 await authManager.initialize()
                 if !authManager.isAuthenticated {
                     print("Merge check failed: No active session.")
                     return 
                 }
            }
        }

        do {
            let hasGamification = LevelManager.shared.currentLevel > 1 || StreakManager.shared.currentStreak > 0
            
            if try SyncManager.shared.hasLocalData(context: modelContext) || hasGamification {
                // Ask user what to do
                showingMergeAlert = true
            } else {
                // No local data, just sync (pull) and close
                await SyncManager.shared.sync(container: modelContext.container)
                dismiss()
            }
        } catch {
            print("Merge check error: \(error)")
            dismiss()
        }
    }
    
    private func handleGoogleSignIn() {
        Task {
            do {
                try await authManager.signInWithGoogle()
                await checkMergeRequirements()
            } catch {
                print(error)
                authManager.errorMessage = error.localizedDescription
                showingAlert = true
            }
        }
    }
}



#Preview {
    LoginView()
}
