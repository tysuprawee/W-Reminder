//
//  AuthManager.swift
//  W Reminder
//
//  Created for Cloud Sync
//

import SwiftUI
import Supabase

@Observable
final class AuthManager {
    static let shared = AuthManager()
    
    private(set) var client: SupabaseClient
    var session: Session?
    var user: User?
    var profile: Profile?
    
    // Auth State
    var isAuthenticated: Bool { session != nil }
    var isLoading = false
    var errorMessage: String?
    var successMessage: String?
    
    private init() {
        self.client = SupabaseClient(
            supabaseURL: SupabaseConfig.projectURL,
            supabaseKey: SupabaseConfig.apiKey
        )
    }
    
    func initialize() async {
        do {
            self.session = try await client.auth.session
            self.user = try await client.auth.user()
            await fetchProfile()
        } catch {
            print("Auth initialization error: \(error)")
        }
    }
    
    // MARK: - Sign In / Sign Up
    
    func signIn(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let session = try await client.auth.signIn(email: email, password: password)
            self.session = session
            self.user = session.user
            await fetchProfile()
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func signUp(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let _ = try await client.auth.signUp(email: email, password: password)
            // Note: Depending on Supabase settings, user might need to verify email
            successMessage = "Account created! Please check your email to verify your account."
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func signInWithGoogle() async throws {
        // Build the redirect URL for mobile
        // The scheme must be registered in Info.plist (e.g. com.wreminder.app)
        // URL: com.wreminder.app://login-callback
        guard let url = URL(string: "com.wreminder.app://login-callback") else { return }
        
        do {
            // Using ASWebAuthenticationSession flow via Supabase helper if available,
            // or the generic OAuth flow.
            // For iOS, Supabase Swift v2+ provides OAuth handlers.
            // We use the PKCE flow.
            try await client.auth.signInWithOAuth(
                provider: .google,
                redirectTo: url
            )
        } catch {
            print("Google Sign In Error: \(error)")
            throw error
        }
    }
    
    func signOut() async {
        do {
            try await client.auth.signOut()
            session = nil
            user = nil
            profile = nil
        } catch {
            print("Sign out error: \(error)")
        }
    }
    
    // MARK: - Profile
    
    func fetchProfile() async {
        guard let userId = user?.id else { return }
        
        do {
            let profile: Profile = try await client
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            self.profile = profile
        } catch {
            print("Error fetching profile: \(error)")
        }
    }
    
    // Handle URL from deep link (for OAuth)
    func handleIncomingURL(_ url: URL) {
        Task {
            do {
                try await client.auth.session(from: url)
                await initialize()
            } catch {
                print("Handle URL error: \(error)")
            }
        }
    }
}

// MARK: - Models

struct Profile: Codable {
    let id: UUID
    let email: String?
    let fullName: String?
    let avatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
    }
}
