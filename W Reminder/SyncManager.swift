//
//  SyncManager.swift
//  W Reminder
//
//  Created for Cloud Sync
//

import Foundation
import SwiftData
import Supabase

// Payload Struct for Main Actor Data Capture
struct PushPayload {
    let tags: [SyncManager.CloudTag]
    let checklists: [CloudSimpleChecklist]
    let checklistTags: [CloudChecklistTag]
    let milestones: [CloudMilestone]
    let milestoneItems: [CloudMilestoneItem]
    let milestoneTags: [CloudMilestoneTag]
}

@MainActor
@Observable
final class SyncManager {
    static let shared = SyncManager()
    
    nonisolated private let client: SupabaseClient
    
    var isSyncing = false
    var lastSyncTime: Date?
    var errorMessage: String?
    
    private init() {
        self.client = AuthManager.shared.client
    }
    
    // MARK: - Merge / Conflict Helpers
    
    @MainActor
    func hasLocalData(context: ModelContext) throws -> Bool {
        let checklists = try context.fetch(FetchDescriptor<SimpleChecklist>())
        let tags = try context.fetch(FetchDescriptor<Tag>())
        return !checklists.isEmpty || !tags.isEmpty
    }
    
    @MainActor
    func deleteLocalData(context: ModelContext) throws {
        // Explicitly fetch and delete to ensure reliability and handle relationships
        let checklists = try context.fetch(FetchDescriptor<SimpleChecklist>())
        for list in checklists {
            context.delete(list)
        }
        
        let tags = try context.fetch(FetchDescriptor<Tag>())
        for tag in tags {
            context.delete(tag)
        }
        
        // Explicitly delete Milestones (Checklist)
        let milestones = try context.fetch(FetchDescriptor<Checklist>())
        for milestone in milestones {
            context.delete(milestone)
        }
        
        // ChecklistItems are cascaded, but to be 100% sure we can delete orphans or just confirm deletion
        // SwiftData cascade should handle it.
        // clean up any remaining items just in case (orphans)
        try context.save() // Ensure changes are committed immediately
        print("Local data deleted successfully.")
    }
    
    @MainActor
    func regenerateIDs(context: ModelContext) throws {
        // Regenerate IDs for all local data so they are treated as NEW records for the current user
        // This effectively "Clones" the data for the new account and avoids RLS conflicts with old owners.
        
        let tags = try context.fetch(FetchDescriptor<Tag>())
        var tagMap: [UUID: UUID] = [:] // Old -> New
        
        for tag in tags {
            let oldID = tag.id
            let newID = UUID()
            tag.id = newID // Assuming ID is mutable, otherwise we'd need to recreate
            tagMap[oldID] = newID
        }
        
        let checklists = try context.fetch(FetchDescriptor<SimpleChecklist>())
        for list in checklists {
            list.id = UUID() 
            // Also update any Many-to-Many relationships if they store IDs explicitly (SwiftData usually handles object links)
            // But our Junction table (ChecklistTags) logic in sync uses the `id` property.
            // Since SwiftData relationships are object-based, `list.tags` still points to the same `Tag` objects (which now have new IDs).
            // Sync logic will read `tag.id` and see the new ID. So we are good.
        }
        
        try context.save()
    }
    
    // MARK: - Main Sync Loop
    
    // Track current sync task to allow waiting
    private var syncTask: Task<Bool, Never>?

    @discardableResult
    func sync(container: ModelContainer, silent: Bool = false) async -> Bool {
        // 1. Check if a sync is already running. If so, wait for it.
        let existingTask: Task<Bool, Never>? = await MainActor.run {
            // If this request is NOT silent, ensure we show the loading UI immediately
            // even if we are attaching to an existing background task.
            if !silent {
                self.isSyncing = true
            }
            
            // Return existing task if any (checking syncTask instead of isSyncing)
            return syncTask
        }
        
        if let existingTask {
            print("Sync: Already in progress, waiting...")
            return await existingTask.value
        }

        // 2. Start new sync task
        let task = Task {
             return await performSync(container: container)
        }
        
        await MainActor.run {
            self.syncTask = task
            if !silent {
                self.isSyncing = true
            }
        }
        
        let result = await task.value
        
        await MainActor.run {
            self.syncTask = nil
            self.isSyncing = false
        }
        
        return result
    }
    
    nonisolated private func performSync(container: ModelContainer) async -> Bool {
        // Access AuthManager on MainActor to be safe
        let (shouldProceed, uid, payload): (Bool, UUID?, PushPayload?) = await MainActor.run {
             guard let user = AuthManager.shared.user else { return (false, nil, nil) }
             // Capture Payload from Main Context
             do {
                 try container.mainContext.save()
                 let p = try self.preparePushPayload(context: container.mainContext, userId: user.id)
                 return (true, user.id, p)
             } catch {
                 print("Error preparing payload: \(error)")
                 return (false, nil, nil)
             }
        }
        
        guard shouldProceed, let userId = uid, let payload = payload else { return false }
        
        await MainActor.run { 
            print("Sync: Starting for user \(userId)...") 
        }
        
        // 1. BACKGROUND PHASE: Push Changes & Fetch Cloud Data
        // We use a background context only for Deletions and possibly other ops, but Push is now driven by Payload.
        let bgContext = ModelContext(container)
        bgContext.autosaveEnabled = false
        
        do {
            // A. Process Deletions
            try await processDeletions(context: bgContext)
            
            // B. Push Local Changes (Using Payload)
            try await pushTags(payload: payload, userId: userId)
            try await pushChecklists(payload: payload, userId: userId)
            try await pushMilestones(payload: payload, userId: userId)
            
            // C. Fetch Cloud Data
            async let cloudTagsTask: [CloudTag] = client.from("tags").select().execute().value
            async let cloudSimpleListsTask: [CloudSimpleChecklist] = client.from("simple_checklists").select().execute().value
            async let cloudSimpleLinksTask: [CloudChecklistTag] = client.from("checklist_tags").select().execute().value
            
            async let cloudMilestonesTask: [CloudMilestone] = client.from("milestones").select().execute().value
            async let cloudMilestoneItemsTask: [CloudMilestoneItem] = client.from("milestone_items").select().execute().value
            async let cloudMilestoneLinksTask: [CloudMilestoneTag] = client.from("milestone_tags").select().execute().value
            
            let (cloudTags, cloudSimpleLists, cloudSimpleLinks, cloudMilestones, cloudMilestoneItems, cloudMilestoneLinks) = try await (cloudTagsTask, cloudSimpleListsTask, cloudSimpleLinksTask, cloudMilestonesTask, cloudMilestoneItemsTask, cloudMilestoneLinksTask)

            // 2. MAIN ACTOR PHASE: Merge logic
            // We apply changes to the MAIN CONTEXT to ensure we respect the absolute latest UI state.
            return await MainActor.run {
                let mainContext = container.mainContext
                do {
                    let tagsMap = try mergeTags(context: mainContext, cloudTags: cloudTags)
                    try mergeChecklists(context: mainContext, cloudLists: cloudSimpleLists, cloudLinks: cloudSimpleLinks, tagsMap: tagsMap)
                    try mergeMilestones(context: mainContext, cloudLists: cloudMilestones, cloudItems: cloudMilestoneItems, cloudLinks: cloudMilestoneLinks, tagsMap: tagsMap)
                    
                    try mainContext.save()
                    print("Sync: Completed & Merged on Main Context.")
                    self.lastSyncTime = Date()
                    return true
                } catch {
                    print("Sync Merge Error: \(error)")
                    self.errorMessage = error.localizedDescription
                    return false
                }
            }
            
        } catch {
            await MainActor.run {
                print("Sync Push/Fetch Error: \(error)")
                self.errorMessage = error.localizedDescription
            }
            return false
        }
    }
    
    @MainActor
    private func preparePushPayload(context: ModelContext, userId: UUID) throws -> PushPayload {
        // Fetch all data from Main Context
        let tags = try context.fetch(FetchDescriptor<Tag>())
        let tagDTOs = tags.map { CloudTag(id: $0.id, userId: userId, name: $0.name, colorHex: $0.colorHex, isTextWhite: $0.isTextWhite) }
        
        let checklists = try context.fetch(FetchDescriptor<SimpleChecklist>())
        var checklistDTOs: [CloudSimpleChecklist] = []
        var checklistTagDTOs: [CloudChecklistTag] = []
        
        // Create a Set of valid Tag IDs to prevent FK violations
        let validTagIds = Set(tagDTOs.map { $0.id })
        
        for list in checklists {
            checklistDTOs.append(CloudSimpleChecklist(
                id: list.id, userId: userId, title: list.title, notes: list.notes,
                dueDate: list.dueDate, remind: list.remind, isDone: list.isDone,
                isStarred: list.isStarred, userOrder: list.userOrder,
                recurrenceRule: list.recurrenceRule, completedAt: list.completedAt,
                updatedAt: list.updatedAt
            ))
            
            // Deduplicate & Validate tags
            let uniqueTags = Set(list.tags)
            for tag in uniqueTags {
                if validTagIds.contains(tag.id) {
                    checklistTagDTOs.append(CloudChecklistTag(checklistId: list.id, tagId: tag.id))
                }
            }
        }
        
        let milestones = try context.fetch(FetchDescriptor<Checklist>())
        var milestoneDTOs: [CloudMilestone] = []
        var milestoneTagDTOs: [CloudMilestoneTag] = []
        var milestoneItemDTOs: [CloudMilestoneItem] = []
        
        for list in milestones {
            milestoneDTOs.append(CloudMilestone(
                id: list.id, userId: userId, title: list.title, notes: list.notes,
                createdAt: list.createdAt, dueDate: list.dueDate, remind: list.remind,
                isDone: list.isDone, isStarred: list.isStarred, userOrder: list.userOrder, recurrenceRule: list.recurrenceRule, completedAt: list.completedAt, updatedAt: list.updatedAt
            ))
            
            // Deduplicate & Validate tags
            let uniqueTags = Set(list.tags)
            for tag in uniqueTags {
                if validTagIds.contains(tag.id) {
                    milestoneTagDTOs.append(CloudMilestoneTag(milestoneId: list.id, tagId: tag.id))
                }
            }
            
            for item in list.items {
                milestoneItemDTOs.append(CloudMilestoneItem(id: item.id, milestoneId: list.id, text: item.text, isDone: item.isDone, position: item.position))
            }
        }
        
        return PushPayload(
            tags: tagDTOs,
            checklists: checklistDTOs,
            checklistTags: checklistTagDTOs,
            milestones: milestoneDTOs,
            milestoneItems: milestoneItemDTOs,
            milestoneTags: milestoneTagDTOs
        )
    }
    
    // MARK: - Deletion Logic
    
    @MainActor
    func registerDeletion(of object: any PersistentModel, context: ModelContext) {
        let table: String
        let id: UUID
        
        if let checklist = object as? SimpleChecklist {
            table = "simple_checklists"
            id = checklist.id
        } else if let milestone = object as? Checklist {
            table = "milestones"
            id = milestone.id
        } else if let tag = object as? Tag {
            table = "tags"
            id = tag.id
        } else {
            return
        }
        
        let record = DeletedRecord(targetID: id, table: table)
        context.insert(record)
    }

    nonisolated private func processDeletions(context: ModelContext) async throws {
        let deletedRecords = try context.fetch(FetchDescriptor<DeletedRecord>())
        guard !deletedRecords.isEmpty else { return }
        
        print("Sync: Processing \(deletedRecords.count) deletions...")
        for record in deletedRecords {
             try await client.from(record.table).delete().eq("id", value: record.targetID).execute()
             context.delete(record)
        }
        try context.save()
    }
    
    // MARK: - Push Logic (Background)
    
    nonisolated private func pushTags(payload: PushPayload, userId: UUID) async throws {
        for dto in payload.tags {
            try await client.from("tags").upsert(dto).execute()
        }
    }
    
    nonisolated private func pushChecklists(payload: PushPayload, userId: UUID) async throws {
        for dto in payload.checklists {
            try await client.from("simple_checklists").upsert(dto).execute()
            
            // Delete existing tags for this checklist
            try await client.from("checklist_tags").delete().eq("checklist_id", value: dto.id).execute()
        }
        // Insert all new links (batch if possible, but singular for simplicity/safety)
        // Wait, deleting per checklist is fine.
        // But invalidating links?
        // We need to filter links for this checklist?
        // Ah, optimizing:
        // We can just iterate the `checklistTags` for the current checklist ID.
        
        // Better:
        let linksByChecklist = Dictionary(grouping: payload.checklistTags, by: { $0.checklistId })
        
        for dto in payload.checklists {
            // Already upserted dto
            // Relationships:
            if let specificLinks = linksByChecklist[dto.id], !specificLinks.isEmpty {
                 try await client.from("checklist_tags").insert(specificLinks).execute()
            }
        }
    }
    
    nonisolated private func pushMilestones(payload: PushPayload, userId: UUID) async throws {
        let linksByMilestone = Dictionary(grouping: payload.milestoneTags, by: { $0.milestoneId })
        let itemsByMilestone = Dictionary(grouping: payload.milestoneItems, by: { $0.milestoneId })

        for dto in payload.milestones {
            try await client.from("milestones").upsert(dto).execute()
            
            // Tags
            try await client.from("milestone_tags").delete().eq("milestone_id", value: dto.id).execute()
            if let specificLinks = linksByMilestone[dto.id], !specificLinks.isEmpty {
                try await client.from("milestone_tags").insert(specificLinks).execute()
            }
            
            // Items
            try await client.from("milestone_items").delete().eq("milestone_id", value: dto.id).execute()
            if let specificItems = itemsByMilestone[dto.id], !specificItems.isEmpty {
                try await client.from("milestone_items").insert(specificItems).execute()
            }
        }
    }
    
    // MARK: - Merge Logic (Main Actor)
    
    @MainActor
    private func mergeTags(context: ModelContext, cloudTags: [CloudTag]) throws -> [UUID: Tag] {
        let localTags = try context.fetch(FetchDescriptor<Tag>())
        var tagsMap: [UUID: Tag] = [:]
        
        // 1. Pre-fill map with all local tags to prevent detaching local-only tags
        for tag in localTags {
            tagsMap[tag.id] = tag
        }
        
        // Prevent Resurrection: Ignore items we have explicitly deleted locally
        let deletedRecords = try context.fetch(FetchDescriptor<DeletedRecord>())
        let deletedIDs = Set(deletedRecords.map { $0.targetID })
        
        for cloudTag in cloudTags {
            let tagID = cloudTag.id
            
            // If we deleted this locally, DO NOT resurrect it from cloud
            if deletedIDs.contains(tagID) {
                continue
            }
            
            if let existing = tagsMap[tagID] {
                // Update properties
                if existing.name != cloudTag.name { existing.name = cloudTag.name }
                if existing.colorHex != cloudTag.colorHex { existing.colorHex = cloudTag.colorHex }
                if existing.isTextWhite != cloudTag.isTextWhite { existing.isTextWhite = cloudTag.isTextWhite }
            } else {
                // Insert New from Cloud
                let newTag = Tag(id: tagID, name: cloudTag.name, colorHex: cloudTag.colorHex, isTextWhite: cloudTag.isTextWhite)
                context.insert(newTag)
                tagsMap[tagID] = newTag
            }
        }
        return tagsMap
    }
    
    @MainActor
    private func mergeChecklists(context: ModelContext, cloudLists: [CloudSimpleChecklist], cloudLinks: [CloudChecklistTag], tagsMap: [UUID: Tag]) throws {
        let localLists = try context.fetch(FetchDescriptor<SimpleChecklist>())
        
        // Prevent Resurrection: Ignore items we have explicitly deleted locally
        let deletedRecords = try context.fetch(FetchDescriptor<DeletedRecord>())
        let deletedIDs = Set(deletedRecords.map { $0.targetID })
        
        let linksByChecklist = Dictionary(grouping: cloudLinks, by: { $0.checklistId })
        
        for cloudList in cloudLists {
            guard !deletedIDs.contains(cloudList.id) else { continue }
            
            let listID = cloudList.id
            let listToUpdate: SimpleChecklist
            
            if let existing = localLists.first(where: { $0.id == listID }) {
                listToUpdate = existing
                
                // CONFLICT STRATEGY: TIMESTAMP BASED
                // If Cloud is Newer -> Overwrite Local
                // If Local is Newer (or equal) -> Keep Local
                let cloudUpdated = cloudList.updatedAt ?? .distantPast
                let localUpdated = listToUpdate.updatedAt
                
                // Allow a small buffer? No, strict > is usually best, unless clocks drift.
                // Assuming clocks are reasonable.
                
                if cloudUpdated > localUpdated {
                    listToUpdate.title = cloudList.title
                    listToUpdate.notes = cloudList.notes
                    listToUpdate.dueDate = cloudList.dueDate
                    
                    // Logic: If user completed it locally, but cloud is newer and says not completed...
                    // Sticky Done might still apply if we want to be safe, but strictly timestamp should win.
                    // However, for "Done" specifically, users hate it unchecking.
                    // Let's stick to timestamp win for now.
                    listToUpdate.isDone = cloudList.isDone
                } else {
                    // Local is newer. Keep Local.
                    // EXCEPT: If we want to merge IsDone specially?
                    // Previous sticky logic:
                    if listToUpdate.isDone && !cloudList.isDone {
                         // Keep Local
                    } else if cloudUpdated > localUpdated {
                         // Only overwrite if cloud is genuinely newer
                         // (Already handled in if block above)
                    }
                }
                
                // Always sync these for now or apply timestamp logic?
                // Apply timestamp logic to everything.
                if cloudUpdated > localUpdated {
                    listToUpdate.remind = cloudList.remind
                    listToUpdate.isStarred = cloudList.isStarred
                    listToUpdate.userOrder = cloudList.userOrder
                    listToUpdate.recurrenceRule = cloudList.recurrenceRule
                    listToUpdate.completedAt = cloudList.completedAt
                    listToUpdate.updatedAt = cloudUpdated // Sync the timestamp!
                    
                    // Relationships (Tags) - moved inside timestamp check to prevent overwriting local edits
                    if let links = linksByChecklist[listID] {
                        var newTags: [Tag] = []
                        for link in links {
                            if let tag = tagsMap[link.tagId] {
                                newTags.append(tag)
                            }
                        }
                        listToUpdate.tags = newTags
                    } else {
                        listToUpdate.tags = []
                    }
                }

            } else {
                let newList = SimpleChecklist(
                    title: cloudList.title, notes: cloudList.notes, dueDate: cloudList.dueDate,
                    remind: cloudList.remind, isDone: cloudList.isDone, tags: [],
                    isStarred: cloudList.isStarred, userOrder: cloudList.userOrder,
                    recurrenceRule: cloudList.recurrenceRule, completedAt: cloudList.completedAt,
                    updatedAt: cloudList.updatedAt ?? Date()
                )
                newList.id = listID
                context.insert(newList)
                listToUpdate = newList
                
                // Initialize tags for new list
                if let links = linksByChecklist[listID] {
                    var newTags: [Tag] = []
                    for link in links {
                        if let tag = tagsMap[link.tagId] {
                            newTags.append(tag)
                        }
                    }
                    listToUpdate.tags = newTags
                }
            }
        }
    }

    
    @MainActor
    private func mergeMilestones(context: ModelContext, cloudLists: [CloudMilestone], cloudItems: [CloudMilestoneItem], cloudLinks: [CloudMilestoneTag], tagsMap: [UUID: Tag]) throws {
        let localLists = try context.fetch(FetchDescriptor<Checklist>())
        
        // Prevent Resurrection
        let deletedRecords = try context.fetch(FetchDescriptor<DeletedRecord>())
        let deletedIDs = Set(deletedRecords.map { $0.targetID })
        
        let itemsByMilestone = Dictionary(grouping: cloudItems, by: { $0.milestoneId })
        let linksByMilestone = Dictionary(grouping: cloudLinks, by: { $0.milestoneId })
        
        for cloudList in cloudLists {
            guard !deletedIDs.contains(cloudList.id) else { continue }
            
            let listID = cloudList.id

            let listToUpdate: Checklist
            
            if let existing = localLists.first(where: { $0.id == listID }) {
                listToUpdate = existing
                
                // CONFLICT STRATEGY: TIMESTAMP BASED
                let cloudUpdated = cloudList.updatedAt ?? .distantPast
                let localUpdated = listToUpdate.updatedAt
                
                if cloudUpdated > localUpdated {
                    listToUpdate.title = cloudList.title
                    listToUpdate.notes = cloudList.notes
                    listToUpdate.dueDate = cloudList.dueDate
                    listToUpdate.remind = cloudList.remind
                    listToUpdate.isStarred = cloudList.isStarred
                    listToUpdate.userOrder = cloudList.userOrder
                    listToUpdate.recurrenceRule = cloudList.recurrenceRule
                    listToUpdate.completedAt = cloudList.completedAt
                    listToUpdate.isDone = cloudList.isDone
                    listToUpdate.updatedAt = cloudUpdated
                }
                
                // Sticky Done logic (optional backup)
                if listToUpdate.isDone && !cloudList.isDone && localUpdated >= cloudUpdated {
                    // Keep Local
                }
                
                listToUpdate.createdAt = cloudList.createdAt

            } else {
                let newList = Checklist(
                    title: cloudList.title, notes: cloudList.notes, dueDate: cloudList.dueDate,
                    remind: cloudList.remind, items: [], tags: [], isStarred: cloudList.isStarred,
                    userOrder: cloudList.userOrder, recurrenceRule: cloudList.recurrenceRule, completedAt: cloudList.completedAt,
                    updatedAt: cloudList.updatedAt ?? Date()
                )
                newList.id = listID
                newList.createdAt = cloudList.createdAt
                newList.isDone = cloudList.isDone
                context.insert(newList)
                listToUpdate = newList
                
                // Initialize tags for new milestone
                if let links = linksByMilestone[listID] {
                    var newTags: [Tag] = []
                    for link in links {
                        if let tag = tagsMap[link.tagId] {
                            newTags.append(tag)
                        }
                    }
                    listToUpdate.tags = newTags
                }
            }
            
            // Merge Items (Subtasks) - Trust Cloud for now (complex to track timestamps per item)
            // Or only if Cloud Milestone is newer?
            let cloudUpdated = cloudList.updatedAt ?? .distantPast
            let localUpdated = listToUpdate.updatedAt

            if cloudUpdated > localUpdated {
                let currentCloudItems = itemsByMilestone[listID] ?? []
                var processedItemIDs = Set<UUID>()
                
                for cloudItem in currentCloudItems {
                    processedItemIDs.insert(cloudItem.id)
                    if let existingItem = listToUpdate.items.first(where: { $0.id == cloudItem.id }) {
                        existingItem.text = cloudItem.text
                        existingItem.isDone = cloudItem.isDone 
                        existingItem.position = cloudItem.position
                    } else {
                        let newItem = ChecklistItem(text: cloudItem.text, isDone: cloudItem.isDone, position: cloudItem.position)
                        newItem.id = cloudItem.id
                        newItem.checklist = listToUpdate
                        listToUpdate.items.append(newItem)
                    }
                }
                
                let itemsToDelete = listToUpdate.items.filter { !processedItemIDs.contains($0.id) }
                for item in itemsToDelete {
                    context.delete(item)
                    if let index = listToUpdate.items.firstIndex(of: item) {
                        listToUpdate.items.remove(at: index)
                    }
                }
            }
            
            // Merge Tags - moved inside timestamp check
            if cloudUpdated > localUpdated {
                if let links = linksByMilestone[listID] {
                    var newTags: [Tag] = []
                    for link in links {
                        if let tag = tagsMap[link.tagId] {
                            newTags.append(tag)
                        }
                    }
                    listToUpdate.tags = newTags
                } else {
                    listToUpdate.tags = []
                }
            }
        }
    }

    // MARK: - Cloud DTOs

    struct CloudTag: Codable, Identifiable {
        var id: UUID
        var userId: UUID
        var name: String
        var colorHex: String
        var isTextWhite: Bool
        
        enum CodingKeys: String, CodingKey {
            case id
            case userId = "user_id"
            case name
            case colorHex = "color_hex"
            case isTextWhite = "is_text_white"
        }
    }

}

struct CloudSimpleChecklist: Codable, Identifiable {
    var id: UUID
    var userId: UUID
    var title: String
    var notes: String?
    var dueDate: Date?
    var remind: Bool
    var isDone: Bool
    var isStarred: Bool
    var userOrder: Int
    var recurrenceRule: String?
    var completedAt: Date?
    var updatedAt: Date? // Timestamps for sync
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title, notes
        case dueDate = "due_date"
        case remind
        case isDone = "is_done"
        case isStarred = "is_starred"
        case userOrder = "user_order"
        case recurrenceRule = "recurrence_rule"
        case completedAt = "completed_at"
        case updatedAt = "updated_at"
    }
}

struct CloudChecklistTag: Codable {
    var checklistId: UUID
    var tagId: UUID
    
    enum CodingKeys: String, CodingKey {
        case checklistId = "checklist_id"
        case tagId = "tag_id"
    }
}

// Milestone DTOs
struct CloudMilestone: Codable, Identifiable {
    var id: UUID
    var userId: UUID
    var title: String
    var notes: String?
    var createdAt: Date
    var dueDate: Date?
    var remind: Bool
    var isDone: Bool
    var isStarred: Bool
    var userOrder: Int
    var recurrenceRule: String?
    var completedAt: Date?
    var updatedAt: Date? // Timestamps for sync
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title, notes
        case createdAt = "created_at"
        case dueDate = "due_date"
        case remind
        case isDone = "is_done"
        case isStarred = "is_starred"
        case userOrder = "user_order"
        case recurrenceRule = "recurrence_rule"
        case completedAt = "completed_at"
        case updatedAt = "updated_at"
    }
}

struct CloudMilestoneItem: Codable, Identifiable {
    var id: UUID
    var milestoneId: UUID
    var text: String
    var isDone: Bool
    var position: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case milestoneId = "milestone_id"
        case text
        case isDone = "is_done"
        case position
    }
}

struct CloudMilestoneTag: Codable {
    var milestoneId: UUID
    var tagId: UUID
    
    enum CodingKeys: String, CodingKey {
        case milestoneId = "milestone_id"
        case tagId = "tag_id"
    }
}
