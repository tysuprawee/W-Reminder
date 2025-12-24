//
//  RemoteConfigManager.swift
//  W Reminder
//
//  Created for Version Management
//

import Foundation
import Supabase

struct CloudAppConfig: Codable, Identifiable {
    let id: Int
    let minSupportedVersion: String
    let latestVersion: String
    let forceUpdate: Bool
    let message: String
    let appStoreURL: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case minSupportedVersion = "min_supported_version"
        case latestVersion = "latest_version"
        case forceUpdate = "force_update"
        case message
        case appStoreURL = "app_store_url"
    }
}

class RemoteConfigManager: ObservableObject {
    static let shared = RemoteConfigManager()
    
    @Published var isUpdateRequired: Bool = false
    @Published var updateMessage: String = ""
    @Published var appStoreURL: URL?
    
    // Cache Key
    private let cacheKey = "cached_app_config"
    
    private init() {}
    
    // MARK: - Core Logic
    
    func checkAppVersion() {
        Task {
            do {
                if let config = try await fetchConfigFromSupabase() {
                    saveToCache(config)
                    await evaluate(config: config)
                }
            } catch {
                print("Remote Config Fetch Failed: \(error). Using Cache.")
                if let cached = loadFromCache() {
                    await evaluate(config: cached)
                }
            }
        }
    }
    
    private func fetchConfigFromSupabase() async throws -> CloudAppConfig? {
        // Fetch the FIRST row from 'app_config' table
        let client = AuthManager.shared.client
        let config: CloudAppConfig = try await client
            .from("app_config")
            .select()
            .limit(1)
            .single() // Expecting exactly one row
            .execute()
            .value
            
        return config
    }
    
    @MainActor
    private func evaluate(config: CloudAppConfig) {
        // Get current app version (e.g. "1.04")
        guard let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else { return }
        
        let result = VersionComparator.compare(currentVersion, with: config.minSupportedVersion)
        
        // If current version is LESS than min_supported, block.
        if result == .orderedAscending {
            self.updateMessage = config.message
            self.appStoreURL = URL(string: config.appStoreURL)
            self.isUpdateRequired = true
        } else {
            self.isUpdateRequired = false
        }
    }
    
    // MARK: - Caching
    
    private func saveToCache(_ config: CloudAppConfig) {
        if let encoded = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
        }
    }
    
    private func loadFromCache() -> CloudAppConfig? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(CloudAppConfig.self, from: data)
    }
}

// MARK: - Version Utilities

enum ComparisonResult {
    case orderedAscending  // v1 < v2
    case orderedSame       // v1 == v2
    case orderedDescending // v1 > v2
}

struct VersionComparator {
    /// Compares two version strings (e.g. "1.04" vs "1.05")
    static func compare(_ v1: String, with v2: String) -> ComparisonResult {
        let maxComponents = 3
        
        // Split by "." and filter out non-numeric noise if any
        let components1 = v1.split(separator: ".").compactMap { Int($0) }
        let components2 = v2.split(separator: ".").compactMap { Int($0) }
        
        let count = max(components1.count, components2.count)
        
        for i in 0..<min(count, maxComponents) {
            let val1 = i < components1.count ? components1[i] : 0
            let val2 = i < components2.count ? components2[i] : 0
            
            if val1 < val2 { return .orderedAscending }
            if val1 > val2 { return .orderedDescending }
        }
        
        return .orderedSame
    }
}
