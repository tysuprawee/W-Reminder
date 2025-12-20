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
            VStack(spacing: 24) {
                Spacer()
                
                // Header
                ZStack(alignment: .topLeading) {
                    VStack(spacing: 12) {
                        Image(systemName: "checklist")
                            .font(.system(size: 64))
                            .foregroundStyle(.tint)
                        
                        Text("Welcome to\nW Reminder")
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .padding(.leading)
                }
                .padding(.bottom, 32)
                
                // Form
                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.large)
                    
                    SecureField("Password", text: $password)
                        .textContentType(isSignUp ? .newPassword : .password)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.large)
                }
                .padding(.horizontal)
                
                // Action Buttons
                VStack(spacing: 16) {
                    if authManager.isLoading {
                        ProgressView()
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
                        }
                        
                        // Google Sign In
                        Button {
                            handleGoogleSignIn()
                        } label: {
                            HStack {
                                Image(systemName: "globe") // Placeholder for Google Icon
                                Text("Sign in with Google")
                            }
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Material.regular)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Toggle Mode
                Button {
                    withAnimation {
                        isSignUp.toggle()
                    }
                } label: {
                    Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom)
            }
            .padding()
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
                            await SyncManager.shared.sync(context: modelContext)
                            dismiss()
                        } catch {
                            print("Error clearing local data: \(error)")
                            // If delete fails, we probably shouldn't leave them in a broken state.
                            // But for now, let's assume it works or they can try again.
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
                Text("Logging in will delete all local guest data. This action cannot be undone.")
            }
        }
    }
    

    
    private func handleAuth() {
        Task {
            do {
                if isSignUp {
                    try await authManager.signUp(email: email, password: password)
                    // Success is now handled by AuthManager.successMessage observing
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
            if try SyncManager.shared.hasLocalData(context: modelContext) {
                // Ask user what to do
                showingMergeAlert = true
            } else {
                // No local data, just sync (pull) and close
                await SyncManager.shared.sync(context: modelContext)
                dismiss()
            }
        } catch {
            print("Merge check error: \(error)")
            dismiss()
        }
    }
    
    // Add Google Sign In wrapper to handle merge check too
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
