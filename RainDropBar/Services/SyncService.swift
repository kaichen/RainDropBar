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
        let remoteCollectionIDs = Set(collectionsResponse.map { $0.id })
        
        for response in collectionsResponse {
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
            modelContext.insert(collection)
        }
        
        // Delete local collections not in remote
        let localCollections = try modelContext.fetch(FetchDescriptor<RaindropCollection>())
        for local in localCollections {
            if !remoteCollectionIDs.contains(local.id) {
                modelContext.delete(local)
            }
        }
        
        // Sync raindrops
        let raindropsResponse = try await api.getAllRaindrops()
        let remoteRaindropIDs = Set(raindropsResponse.map { $0.id })
        
        for response in raindropsResponse {
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
            modelContext.insert(raindrop)
        }
        
        // Delete local raindrops not in remote
        let localRaindrops = try modelContext.fetch(FetchDescriptor<Raindrop>())
        for local in localRaindrops {
            if !remoteRaindropIDs.contains(local.id) {
                modelContext.delete(local)
            }
        }
        
        try modelContext.save()
        
        lastSyncTime = Date()
        UserDefaults.standard.set(lastSyncTime, forKey: "lastSyncTime")
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
