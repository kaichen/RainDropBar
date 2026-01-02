//
//  SyncService.swift
//  RainDropBar
//
//  Created by Kai on 2026-01-02.
//

import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class SyncService {
    var isSyncing = false
    var isBackgroundSyncing = false
    var lastSyncTime: Date?
    var error: Error?
    var syncProgress: String?
    
    private var modelContext: ModelContext?
    private var syncTimer: Timer?
    private var backgroundTask: Task<Void, Never>?
    private let initialLoadLimit = 1000
    
    static let shared = SyncService()
    
    private init() {
        lastSyncTime = UserDefaults.standard.object(forKey: "lastSyncTime") as? Date
        debugLog(.sync, "SyncService initialized")
    }
    
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func startAutoSync(interval: TimeInterval = 900) { // 15 minutes
        stopAutoSync()
        syncTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                try? await self?.sync()
            }
        }
    }
    
    func stopAutoSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    func sync() async throws {
        guard let token = TokenManager.shared.token else {
            debugLog(.sync, "Sync failed: no token")
            throw SyncError.noToken
        }
        
        guard let modelContext else {
            debugLog(.sync, "Sync failed: no model context")
            throw SyncError.noModelContext
        }
        
        guard !isSyncing else {
            debugLog(.sync, "Sync skipped: already syncing")
            return
        }
        
        isSyncing = true
        error = nil
        syncProgress = "Starting sync..."
        debugLog(.sync, "Sync started")
        
        defer {
            isSyncing = false
            syncProgress = nil
        }
        
        let api = RaindropAPI(token: token)
        
        let collectionsResponse: [CollectionResponse]
        let raindropsResponse: [RaindropResponse]
        
        do {
            syncProgress = "Fetching collections..."
            debugLog(.sync, "Phase 1: Fetching collections")
            collectionsResponse = try await api.getCollections()
            debugLog(.sync, "Fetched \(collectionsResponse.count) collections")
            
            syncProgress = "Fetching recent bookmarks..."
            debugLog(.sync, "Phase 2: Fetching recent raindrops (limit: \(initialLoadLimit))")
            raindropsResponse = try await api.getRecentRaindrops(limit: initialLoadLimit)
            debugLog(.sync, "Fetched \(raindropsResponse.count) raindrops")
        } catch {
            debugLog(.sync, "Fetch error: \(error.localizedDescription)")
            self.error = error
            throw error
        }
        
        do {
            syncProgress = "Saving data..."
            debugLog(.sync, "Phase 3: Saving to SwiftData")
            try syncCollections(collectionsResponse, in: modelContext)
            try syncRaindrops(raindropsResponse, in: modelContext, deleteOrphans: false)
            try modelContext.save()
            debugLog(.sync, "Data saved successfully")
        } catch {
            debugLog(.sync, "Save error: \(error.localizedDescription)")
            modelContext.rollback()
            self.error = error
            throw error
        }
        
        lastSyncTime = Date()
        UserDefaults.standard.set(lastSyncTime, forKey: "lastSyncTime")
        debugLog(.sync, "Initial sync completed")
        
        if raindropsResponse.count >= initialLoadLimit {
            let startPage = initialLoadLimit / 50
            debugLog(.sync, "Phase 4: Starting background sync from page \(startPage)")
            startBackgroundSync(startPage: startPage, token: token)
        }
    }
    
    private func startBackgroundSync(startPage: Int, token: String) {
        backgroundTask?.cancel()
        backgroundTask = Task { [weak self] in
            guard let self else { return }
            
            await MainActor.run {
                self.isBackgroundSyncing = true
            }
            debugLog(.sync, "Background sync started from page \(startPage)")
            
            let api = RaindropAPI(token: token)
            var page = startPage
            var totalFetched = 0
            
            do {
                while !Task.isCancelled {
                    let response = try await api.getRaindrops(page: page)
                    if response.items.isEmpty { break }
                    
                    totalFetched += response.items.count
                    debugLog(.sync, "Background page \(page): fetched \(response.items.count) items, total: \(totalFetched)")
                    
                    await MainActor.run {
                        guard let ctx = self.modelContext else { return }
                        do {
                            try self.syncRaindrops(response.items, in: ctx, deleteOrphans: false)
                            try ctx.save()
                        } catch {
                            debugLog(.sync, "Background save error: \(error.localizedDescription)")
                        }
                    }
                    
                    if response.items.count < 50 { break }
                    page += 1
                }
                debugLog(.sync, "Background sync completed: \(totalFetched) additional items")
            } catch {
                debugLog(.sync, "Background sync error: \(error.localizedDescription)")
            }
            
            await MainActor.run {
                self.isBackgroundSyncing = false
            }
        }
    }
    
    private func syncCollections(_ responses: [CollectionResponse], in context: ModelContext) throws {
        // Fetch all existing collections
        let existingCollections = try context.fetch(FetchDescriptor<RaindropCollection>())
        let existingByID = Dictionary(uniqueKeysWithValues: existingCollections.map { ($0.id, $0) })
        
        let remoteIDs = Set(responses.map { $0.id })
        
        for response in responses {
            if let existing = existingByID[response.id] {
                // Update existing
                existing.title = response.title
                existing.count = response.count
                existing.cover = response.cover.first ?? ""
                existing.color = response.color ?? ""
                existing.parentID = response.parent?.id
                existing.sortOrder = response.sort
                existing.view = response.view
                existing.isPublic = response.public
                existing.expanded = response.expanded
                existing.lastUpdate = response.lastUpdate
            } else {
                // Insert new
                let collection = RaindropCollection(
                    id: response.id,
                    title: response.title,
                    count: response.count,
                    cover: response.cover.first ?? "",
                    color: response.color ?? "",
                    parentID: response.parent?.id,
                    sortOrder: response.sort,
                    view: response.view,
                    isPublic: response.public,
                    expanded: response.expanded,
                    lastUpdate: response.lastUpdate
                )
                context.insert(collection)
            }
        }
        
        // Delete collections not in remote
        for existing in existingCollections {
            if !remoteIDs.contains(existing.id) {
                context.delete(existing)
            }
        }
    }
    
    private func syncRaindrops(_ responses: [RaindropResponse], in context: ModelContext, deleteOrphans: Bool = false) throws {
        let existingRaindrops = try context.fetch(FetchDescriptor<Raindrop>())
        let existingByID = Dictionary(uniqueKeysWithValues: existingRaindrops.map { ($0.id, $0) })
        
        let remoteIDs = Set(responses.map { $0.id })
        var inserted = 0
        var updated = 0
        
        for response in responses {
            if let existing = existingByID[response.id] {
                existing.title = response.title
                existing.link = response.link
                existing.excerpt = response.excerpt
                existing.note = response.note
                existing.domain = response.domain
                existing.cover = response.cover
                existing.type = response.type
                existing.tags = response.tags
                existing.important = response.important
                existing.collectionID = response.collection.id
                existing.created = response.created
                existing.lastUpdate = response.lastUpdate
                updated += 1
            } else {
                let raindrop = Raindrop(
                    id: response.id,
                    title: response.title,
                    link: response.link,
                    excerpt: response.excerpt,
                    note: response.note,
                    domain: response.domain,
                    cover: response.cover,
                    type: response.type,
                    tags: response.tags,
                    important: response.important,
                    collectionID: response.collection.id,
                    created: response.created,
                    lastUpdate: response.lastUpdate
                )
                context.insert(raindrop)
                inserted += 1
            }
        }
        
        debugLog(.swiftdata, "Raindrops: \(inserted) inserted, \(updated) updated")
        
        if deleteOrphans {
            var deleted = 0
            for existing in existingRaindrops {
                if !remoteIDs.contains(existing.id) {
                    context.delete(existing)
                    deleted += 1
                }
            }
            debugLog(.swiftdata, "Raindrops: \(deleted) deleted")
        }
    }
}

enum SyncError: Error, LocalizedError {
    case noToken
    case noModelContext
    
    var errorDescription: String? {
        switch self {
        case .noToken:
            return "No API token configured"
        case .noModelContext:
            return "Database not initialized"
        }
    }
}
