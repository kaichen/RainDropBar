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
    var lastSyncTime: Date?
    var error: Error?
    
    private var modelContext: ModelContext?
    private var syncTimer: Timer?
    
    static let shared = SyncService()
    
    private init() {
        lastSyncTime = UserDefaults.standard.object(forKey: "lastSyncTime") as? Date
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
            throw SyncError.noToken
        }
        
        guard let modelContext else {
            throw SyncError.noModelContext
        }
        
        guard !isSyncing else { return }
        
        isSyncing = true
        error = nil
        
        defer { isSyncing = false }
        
        let api = RaindropAPI(token: token)
        
        // Sync collections
        let collectionsResponse = try await api.getCollections()
        try syncCollections(collectionsResponse, in: modelContext)
        
        // Sync raindrops
        let raindropsResponse = try await api.getAllRaindrops()
        try syncRaindrops(raindropsResponse, in: modelContext)
        
        try modelContext.save()
        
        lastSyncTime = Date()
        UserDefaults.standard.set(lastSyncTime, forKey: "lastSyncTime")
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
    
    private func syncRaindrops(_ responses: [RaindropResponse], in context: ModelContext) throws {
        // Fetch all existing raindrops
        let existingRaindrops = try context.fetch(FetchDescriptor<Raindrop>())
        let existingByID = Dictionary(uniqueKeysWithValues: existingRaindrops.map { ($0.id, $0) })
        
        let remoteIDs = Set(responses.map { $0.id })
        
        for response in responses {
            if let existing = existingByID[response.id] {
                // Update existing
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
            } else {
                // Insert new
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
            }
        }
        
        // Delete raindrops not in remote
        for existing in existingRaindrops {
            if !remoteIDs.contains(existing.id) {
                context.delete(existing)
            }
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
