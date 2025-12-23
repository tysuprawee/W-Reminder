//
//  AuthManager.swift
//  W Reminder
//
//  Created for Cloud Sync
//

import SwiftUI
import Supabase

@MainActor
@Observable
final class AuthManager {
    static let shared = AuthManager()
    
    nonisolated let client: SupabaseClient
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
        
        // Reset preferences to default
        UserDefaults.standard.removeObject(forKey: "selectedThemeId")
        UserDefaults.standard.removeObject(forKey: "notificationSound")
        
        // Reset Gamification
        await MainActor.run {
            LevelManager.shared.resetLocalData()
            StreakManager.shared.resetLocalData()
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
            
            // Sync Streaks & Gamification (Cloud -> Local)
            await MainActor.run {
                if let cloudStreak = profile.streakCount {
                     // Only overwrite local if cloud data exists
                     StreakManager.shared.updateFromCloud(
                        count: cloudStreak,
                        lastDate: profile.streakLastActive
                     )
                }
                
                // Gamification Config (Robust Import)
                if let exp = profile.experiencePoints, let lvl = profile.level {
                    LevelManager.shared.importFromCloud(
                        exp: exp, 
                        level: lvl, 
                        achievementsString: profile.achievements ?? ""
                    )
                }
                
                // Apply preferences
                if let themeId = profile.themeId {
                    UserDefaults.standard.set(themeId, forKey: "selectedThemeId")
                }
                if let sound = profile.notificationSound {
                    UserDefaults.standard.set(sound, forKey: "notificationSound")
                }
            }
        } catch {
            print("Error fetching profile: \(error)")
        }
    }
    
    // New Function to Push Streak
    func updateStreak(count: Int, lastActive: Date) async {
        guard let userId = user?.id else { return }
        
        let update = ProfileStreakUpdate(
            streakCount: count,
            streakLastActive: lastActive
        )
        
        do {
            try await client
                .from("profiles")
                .update(update)
                .eq("id", value: userId)
                .execute()
        } catch {
             print("Error updating streak: \(error)")
        }
    }
    
    func updateGamification(exp: Int, level: Int, achievements: String) async {
        guard let userId = user?.id else { return }
        
        let update = ProfileGamificationUpdate(
            experiencePoints: exp,
            level: level,
            achievements: achievements
        )
        
        do {
            try await client
                .from("profiles")
                .update(update)
                .eq("id", value: userId)
                .execute()
        } catch {
             print("Error updating gamification: \(error)")
        }
    }
    
    func updateSettings(themeId: String, sound: String) async {
        guard let userId = user?.id else { return }
        
        let update = ProfileUpdate(
            themeId: themeId,
            notificationSound: sound
        )
        
        do {
            try await client
                .from("profiles")
                .update(update)
                .eq("id", value: userId)
                .execute()
        } catch {
            print("Error updating profile settings: \(error)")
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
    let themeId: String?
    let notificationSound: String?
    let streakCount: Int?
    let streakLastActive: Date?
    let experiencePoints: Int?
    let level: Int?
    let achievements: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case themeId = "theme_id"
        case notificationSound = "notification_sound"
        case streakCount = "streak_count"
        case streakLastActive = "streak_last_active"
        case experiencePoints = "experience_points"
        case level
        case achievements
    }
}

struct ProfileUpdate: Encodable {
    let themeId: String
    let notificationSound: String
    
    enum CodingKeys: String, CodingKey {
        case themeId = "theme_id"
        case notificationSound = "notification_sound"
    }
}

struct ProfileStreakUpdate: Encodable {
    let streakCount: Int
    let streakLastActive: Date
    
    enum CodingKeys: String, CodingKey {
        case streakCount = "streak_count"
        case streakLastActive = "streak_last_active"
    }
}

struct ProfileGamificationUpdate: Encodable {
    let experiencePoints: Int
    let level: Int
    let achievements: String
    
    enum CodingKeys: String, CodingKey {
        case experiencePoints = "experience_points"
        case level
        case achievements
    }
}
