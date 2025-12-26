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
    var isAuthenticated: Bool {
        session != nil
    }
    var isLoading = false
    var errorMessage: String?
    var successMessage: String?
    
    // Flag to ensure we only apply cloud preferences (Theme/Sound) once on startup
    // This prevents "fighting" or flickering if the cloud echoes back an update while we are changing it locally.
    private var hasSyncedPreferences = false 
    
    var shouldShowWelcomeBack = false    
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
            await subscribeToProfileUpdates() // Start Realtime
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
            await subscribeToProfileUpdates() // Start Realtime
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // ...
    
    // MARK: - Realtime Subscription
    
    func subscribeToProfileUpdates() async {
        guard let userId = user?.id else { return }
        
        let channel = client.channel("public:profiles:\(userId)")
        
        // Listen for UPDATES specifically
        let subscription = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "profiles",
            filter: "id=eq.\(userId)"
        )
        
        await channel.subscribe()
        
        Task {
            for await _ in subscription {
                await fetchProfile()
            }
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
            
            // Check if Invite Code is missing (for existing users)
            if profile.inviteCode == nil {
                Task {
                    await generateInviteCode()
                }
            }
            
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
                        achievementsString: profile.achievements ?? "",
                        totalTasks: profile.totalTasks ?? 0
                    )
                }
                
                // Apply preferences (Only once on startup to prevent flickering/fighting)
                if !self.hasSyncedPreferences {
                    if let themeId = profile.themeId {
                         UserDefaults.standard.set(themeId, forKey: "selectedThemeId")
                    }
                    if let sound = profile.notificationSound {
                        UserDefaults.standard.set(sound, forKey: "notificationSound")
                    }
                    self.hasSyncedPreferences = true
                }
                
                // Trigger Unlocks Check
                ThemeManager.shared.checkUnlocks() // This toggles showUnlockCelebration
            }
        } catch {
            print("Error fetching profile: \(error)")
        }
    }
    
    func generateInviteCode() async {
        do {
            let _: String = try await client
                .rpc("generate_my_invite_code")
                .execute()
                .value
            
            await fetchProfile() // Refresh to get the new code
        } catch {
            print("Error generating invite code: \(error)")
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
    
    func updateGamification(exp: Int, level: Int, achievements: String, totalTasks: Int) async {
        guard let userId = user?.id else { return }
        
        let update = ProfileGamificationUpdate(
            experiencePoints: exp,
            level: level,
            achievements: achievements,
            totalTasks: totalTasks
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
        
        // Mark this as a local update so we ignore the Realtime echo
        await MainActor.run {
            ThemeSelectionManager.shared.lastLocalUpdate = Date()
        }
        
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

    // MARK: - Referral
    
    func redeemInvite(code: String) async -> (success: Bool, message: String) {
        do {
            struct RedeemParams: Codable { let code: String }
            struct RedeemResponse: Codable { let success: Bool; let message: String }
            
            let response: RedeemResponse = try await client
                .rpc("redeem_invite", params: RedeemParams(code: code))
                .execute()
                .value
                
            if response.success {
                await fetchProfile() // Refresh local profile to show "Redeemed" state
            }
            return (response.success, response.message)
            
        } catch {
             print("Error redeeming code: \(error)")
             return (false, error.localizedDescription)
        }
    }

    func saveDeviceToken(_ token: String) async {
        guard let userId = user?.id else { return }
        
        // Upsert Token
        let tokenObj = DeviceToken(userId: userId, token: token)
        
        do {
            try await client
                .from("device_tokens")
                .upsert(tokenObj)
                .execute()
        } catch {
            print("Error saving device token: \(error)")
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
    let totalTasks: Int?
    
    // New Fields
    let inviteCode: String?
    let invitationsCount: Int?
    let redeemedByCode: String?
    
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
        case totalTasks = "total_tasks"
        case inviteCode = "invite_code"
        case invitationsCount = "invitations_count"
        case redeemedByCode = "redeemed_by_code"
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



// MARK: - Models

struct DeviceToken: Codable {
    let userId: UUID
    let token: String
    let platform: String = "ios"
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case token
        case platform
    }
}

struct ProfileGamificationUpdate: Encodable {
    let experiencePoints: Int
    let level: Int
    let achievements: String
    let totalTasks: Int
    
    enum CodingKeys: String, CodingKey {
        case experiencePoints = "experience_points"
        case level
        case achievements
        case totalTasks = "total_tasks"
    }
}
