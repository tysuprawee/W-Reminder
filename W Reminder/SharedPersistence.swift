//
//  SharedPersistence.swift
//  W Reminder
//

import SwiftData
import Foundation

class SharedPersistence {
    static let shared = SharedPersistence()
    
    // REPLACE THIS with your actual App Group ID from Xcode Capabilities
    static let appGroupIdentifier = "group.com.tysuprawee.W-Reminder"
    
    var container: ModelContainer
    
    init() {
        let schema = Schema([
            Checklist.self,
            ChecklistItem.self,
            SimpleChecklist.self,
            Tag.self,
            DeletedRecord.self,
        ])
        
        // Define the App Group URL
        let url: URL
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier) {
            url = groupURL.appendingPathComponent("WReminder.sqlite")
        } else {
            print("CRITICAL: Could not find App Group Container. Falling back to default documents directory.")
            url = URL.applicationSupportDirectory.appending(path: "WReminder.sqlite")
        }
        
        let configuration = ModelConfiguration(url: url)

        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
            print("Success: ModelContainer created at \(url.path)")
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}
