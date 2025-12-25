//
//  W_ReminderApp.swift
//  W Reminder
//
//  Created by Suprawee Pongpeeradech on 11/20/25.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct W_ReminderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    
    // Use the shared persistence controller (App Group aware)
    var sharedModelContainer: ModelContainer = SharedPersistence.shared.container

    init() {
        // Ask for notification permission when the app starts
        NotificationManager.shared.requestAuthorization()
        
        // Restore Streak state on launch
        StreakManager.shared.checkStreak()
    }

    // State for RemoteConfig
    @StateObject private var remoteConfig = RemoteConfigManager.shared
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                
                // Blocking Update Screen
                if remoteConfig.isUpdateRequired {
                    Theme.default.background.edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 20) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(Theme.default.accent)
                        
                        Text("Update Required")
                            .font(.title.bold())
                            .foregroundStyle(Theme.default.primary)
                        
                        Text(remoteConfig.updateMessage)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Theme.default.secondary)
                            .padding(.horizontal)
                        
                // Show Current Version
                        if let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                            Text("Your Version: \(currentVersion)")
                                .font(.caption)
                                .foregroundStyle(Theme.default.secondary.opacity(0.8))
                        }
                        
                        if let url = remoteConfig.appStoreURL {
                            Link(destination: url) {
                                Text("Update Now")
                                    .font(.headline)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Theme.default.accent)
                                    .foregroundColor(.white) // Button text usually white on accent
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal, 40)
                        }
                    }
                    .padding()
                    .background(Theme.default.background) // Or a slightly lighter shade if desired, but consistent
                    .cornerRadius(20)
                    .shadow(radius: 10)
                    .padding()
                }
            }
            .task {
                remoteConfig.checkAppVersion()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    print("DEBUG: App became active, checking version...")
                    remoteConfig.checkAppVersion()
                }
            }
        }
        .modelContainer(sharedModelContainer)

    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }
}
