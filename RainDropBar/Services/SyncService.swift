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
    
    private var modelContainer: ModelContainer?
    private var engine: SyncEngine?
    private var syncTimer: Timer?
    private var backgroundTask: Task<Void, Never>?
    private var isConfigured = false
    private let initialLoadLimit = 1000
    
    static let shared = SyncService()
    
    private init() {
        lastSyncTime = UserDefaults.standard.object(forKey: "lastSyncTime") as? Date
        debugLog(.sync, "SyncService initialized")
    }
    
    func configure(modelContainer: ModelContainer) {
        guard !isConfigured else {
            debugLog(.sync, "SyncService already configured, skipping")
            return
        }
        self.modelContainer = modelContainer
        self.engine = SyncEngine(container: modelContainer)
        self.isConfigured = true
        debugLog(.sync, "SyncService configured with ModelContainer")
    }
    
    func startOnLaunchIfPossible() {
        guard isConfigured else {
            debugLog(.sync, "startOnLaunchIfPossible: not configured")
            return
        }
        
        guard TokenManager.shared.hasToken else {
            debugLog(.sync, "startOnLaunchIfPossible: no token")
            return
        }
        
        debugLog(.sync, "startOnLaunchIfPossible: starting sync and timer")
        
        startAutoSync()
        
        Task.detached { [weak self] in
            do {
                try await self?.sync()
            } catch {
                debugLog(.sync, "Launch sync failed: \(error.localizedDescription)")
            }
        }
    }
    
    func startAutoSync(interval: TimeInterval = 900) {
        stopAutoSync()
        debugLog(.sync, "Starting auto-sync timer (interval: \(interval)s)")
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
            self.error = SyncError.noToken
            throw SyncError.noToken
        }
        
        guard let engine else {
            debugLog(.sync, "Sync failed: no engine (not configured)")
            self.error = SyncError.noModelContext
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
            debugLog(.sync, "Phase 3: Saving to SwiftData (background)")
            try await engine.applyInitialSync(
                collections: collectionsResponse,
                raindrops: raindropsResponse
            )
            debugLog(.sync, "Data saved successfully")
        } catch {
            debugLog(.sync, "Save error: \(error.localizedDescription)")
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
        
        guard let engine else { return }
        
        backgroundTask = Task.detached { [weak self] in
            await MainActor.run {
                self?.isBackgroundSyncing = true
            }
            debugLog(.sync, "Background sync started from page \(startPage)")
            
            let api = RaindropAPI(token: token)
            var page = startPage
            var totalFetched = 0
            var raindropIndex: [Int: Raindrop] = [:]
            
            do {
                while !Task.isCancelled {
                    let response = try await api.getRaindrops(page: page)
                    if response.items.isEmpty { break }
                    
                    totalFetched += response.items.count
                    debugLog(.sync, "Background page \(page): fetched \(response.items.count) items, total: \(totalFetched)")
                    
                    try await engine.applyRaindropPage(response.items, existingIndex: &raindropIndex)
                    
                    if response.items.count < 50 { break }
                    page += 1
                }
                debugLog(.sync, "Background sync completed: \(totalFetched) additional items")
            } catch {
                debugLog(.sync, "Background sync error: \(error.localizedDescription)")
            }
            
            await MainActor.run {
                self?.isBackgroundSyncing = false
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
