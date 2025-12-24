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
                    Color.black.edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 20) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.white)
                        
                        Text("Update Required")
                            .font(.title.bold())
                            .foregroundStyle(.white)
                        
                        Text(remoteConfig.updateMessage)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal)
                        
                        if let url = remoteConfig.appStoreURL {
                            Link(destination: url) {
                                Text("Update Now")
                                    .font(.headline)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal, 40)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(20)
                    .padding()
                }
            }
            .task {
                remoteConfig.checkAppVersion()
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
