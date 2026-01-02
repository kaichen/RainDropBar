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
    var progress = SyncProgress.idle
    var lastSyncTime: Date?
    var error: Error?
    var canCancel: Bool { currentTask != nil && isSyncing }
    
    private var modelContainer: ModelContainer?
    private var engine: SyncEngine?
    private var syncTimer: Timer?
    private var currentTask: Task<Void, Never>?
    private var isConfigured = false
    private(set) var syncState = SyncState.load()
    
    private let perPage = 50
    
    static let shared = SyncService()
    
    private init() {
        lastSyncTime = syncState.lastSuccessfulSyncAt
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
        
        Task {
            await migrateFromLegacySyncIfNeeded()
        }
    }
    
    private func migrateFromLegacySyncIfNeeded() async {
        guard let engine else { return }
        guard syncState.cursorLastUpdate == nil else { return }
        
        do {
            let existingCount = try await engine.getRaindropCount()
            if existingCount > 0 {
                let maxLastUpdate = try await engine.getMaxLastUpdate()
                syncState.cursorLastUpdate = maxLastUpdate
                syncState.hasCompletedFullBackfill = false
                syncState.save()
                debugLog(.sync, "Migrated from legacy sync: \(existingCount) items, cursor: \(maxLastUpdate?.description ?? "nil")")
            }
        } catch {
            debugLog(.sync, "Migration check failed: \(error.localizedDescription)")
        }
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
            await self?.sync()
        }
    }
    
    func startAutoSync(interval: TimeInterval = 900) {
        stopAutoSync()
        debugLog(.sync, "Starting auto-sync timer (interval: \(interval)s)")
        syncTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.sync()
            }
        }
    }
    
    func stopAutoSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    func cancelSync() {
        currentTask?.cancel()
        currentTask = nil
        progress = SyncProgress(phase: .cancelled)
        isSyncing = false
        debugLog(.sync, "Sync cancelled by user")
    }
    
    func forceFullResync() async {
        syncState.reset()
        await sync(mode: .forceFullResync)
    }
    
    func sync(mode: SyncMode? = nil) async {
        guard let token = TokenManager.shared.token else {
            debugLog(.sync, "Sync failed: no token")
            self.error = SyncError.noToken
            return
        }
        
        guard let engine else {
            debugLog(.sync, "Sync failed: no engine (not configured)")
            self.error = SyncError.noModelContext
            return
        }
        
        guard !isSyncing else {
            debugLog(.sync, "Sync skipped: already syncing")
            return
        }
        
        let effectiveMode = mode ?? (syncState.hasCompletedFullBackfill ? .incremental : .fullBackfill)
        
        isSyncing = true
        error = nil
        progress = SyncProgress(phase: .starting)
        syncState.lastAttemptAt = Date()
        
        debugLog(.sync, "Sync started (mode: \(effectiveMode))")
        
        currentTask = Task.detached { [weak self] in
            guard let self else { return }
            
            do {
                let api = RaindropAPI(token: token)
                
                switch effectiveMode {
                case .fullBackfill, .forceFullResync:
                    try await self.performFullBackfill(api: api, engine: engine)
                case .incremental:
                    try await self.performIncrementalSync(api: api, engine: engine)
                }
                
                await MainActor.run {
                    self.syncState.lastSuccessfulSyncAt = Date()
                    self.syncState.checkpoint = nil
                    self.syncState.save()
                    self.lastSyncTime = self.syncState.lastSuccessfulSyncAt
                    self.progress = SyncProgress(phase: .completed)
                    self.isSyncing = false
                    self.currentTask = nil
                }
                debugLog(.sync, "Sync completed successfully")
                
            } catch is CancellationError {
                debugLog(.sync, "Sync was cancelled")
                await MainActor.run {
                    self.progress = SyncProgress(phase: .cancelled)
                    self.isSyncing = false
                    self.currentTask = nil
                }
            } catch {
                debugLog(.sync, "Sync failed: \(error.localizedDescription)")
                await MainActor.run {
                    self.error = error
                    self.progress = SyncProgress(phase: .failed)
                    self.isSyncing = false
                    self.currentTask = nil
                }
            }
        }
    }
    
    // MARK: - Full Backfill
    
    private func performFullBackfill(api: RaindropAPI, engine: SyncEngine) async throws {
        await updateProgress(.fetchingCollections)
        
        let collections = try await api.getCollections()
        try Task.checkCancellation()
        debugLog(.sync, "Fetched \(collections.count) collections")
        
        try await engine.syncCollections(collections)
        
        let estimatedItems = collections.reduce(0) { $0 + $1.count }
        var knownTotalItems: Int? = nil
        debugLog(.sync, "Estimated items from collections: \(estimatedItems)")
        
        await MainActor.run {
            self.progress.phase = .syncingBookmarks
            self.progress.totalUnits = nil
            self.progress.completedUnits = 0
        }
        
        var raindropIndex: [Int: Raindrop] = [:]
        var page = 0
        var maxLastUpdate: Date?
        var totalItemsFetched = 0
        
        while true {
            try Task.checkCancellation()
            
            let response = try await api.getRaindrops(collectionID: 0, page: page, perPage: perPage)
            
            if response.items.isEmpty { break }
            
            if knownTotalItems == nil, let count = response.count {
                knownTotalItems = count
                let totalPages = (count + perPage - 1) / perPage
                await MainActor.run {
                    self.progress.totalUnits = totalPages
                }
                debugLog(.sync, "API reports \(count) total items (~\(totalPages) pages)")
            }
            
            try await engine.applyRaindropPage(response.items, existingIndex: &raindropIndex)
            
            for item in response.items {
                if maxLastUpdate == nil || item.lastUpdate > maxLastUpdate! {
                    maxLastUpdate = item.lastUpdate
                }
            }
            
            totalItemsFetched += response.items.count
            
            await MainActor.run {
                let currentPage = page + 1
                if let total = self.progress.totalUnits {
                    self.progress.totalUnits = max(total, currentPage)
                }
                self.progress.completedUnits = currentPage
                self.progress.currentPage = page
                self.progress.itemsApplied = totalItemsFetched
            }
            
            debugLog(.sync, "Page \(page): \(response.items.count) items (total: \(totalItemsFetched))")
            
            if let known = knownTotalItems, totalItemsFetched >= known {
                debugLog(.sync, "Reached known total count, stopping")
                break
            }
            
            if response.items.count < perPage { break }
            page += 1
            
            if page % 10 == 0 {
                await MainActor.run {
                    self.syncState.checkpoint = SyncCheckpoint(
                        mode: .fullBackfill,
                        collectionID: 0,
                        page: page,
                        startedAt: self.syncState.lastAttemptAt ?? Date(),
                        itemsProcessed: totalItemsFetched
                    )
                    self.syncState.save()
                }
            }
        }
        
        await updateProgress(.finalizing)
        
        await MainActor.run {
            self.syncState.hasCompletedFullBackfill = true
            self.syncState.cursorLastUpdate = maxLastUpdate
            self.syncState.checkpoint = nil
        }
        
        debugLog(.sync, "Full backfill completed: \(totalItemsFetched) items, cursor: \(maxLastUpdate?.description ?? "nil")")
    }
    
    // MARK: - Incremental Sync
    
    private func performIncrementalSync(api: RaindropAPI, engine: SyncEngine) async throws {
        await updateProgress(.fetchingCollections)
        
        let collections = try await api.getCollections()
        try Task.checkCancellation()
        
        try await engine.syncCollections(collections)
        
        await MainActor.run {
            self.progress.phase = .syncingBookmarks
            self.progress.totalUnits = nil
        }
        
        let cursorDate = syncState.cursorLastUpdate
        let overlapWindow: TimeInterval = 600  // 10 minutes overlap for safety
        let effectiveCursor = cursorDate.map { $0.addingTimeInterval(-overlapWindow) }
        
        debugLog(.sync, "Incremental sync from cursor: \(cursorDate?.description ?? "beginning")")
        
        var raindropIndex: [Int: Raindrop] = [:]
        var page = 0
        var maxLastUpdate = cursorDate
        var totalItemsFetched = 0
        var reachedCursor = false
        
        while !reachedCursor {
            try Task.checkCancellation()
            
            let response = try await api.getRaindrops(
                collectionID: 0,
                page: page,
                perPage: perPage,
                sort: "-lastUpdate"
            )
            
            if response.items.isEmpty { break }
            
            var itemsToApply: [RaindropResponse] = []
            
            for item in response.items {
                if let cursor = effectiveCursor, item.lastUpdate < cursor {
                    reachedCursor = true
                    break
                }
                itemsToApply.append(item)
                
                if maxLastUpdate == nil || item.lastUpdate > maxLastUpdate! {
                    maxLastUpdate = item.lastUpdate
                }
            }
            
            if !itemsToApply.isEmpty {
                try await engine.applyRaindropPage(itemsToApply, existingIndex: &raindropIndex)
                totalItemsFetched += itemsToApply.count
            }
            
            await MainActor.run {
                self.progress.currentPage = page
                self.progress.itemsApplied = totalItemsFetched
            }
            
            debugLog(.sync, "Incremental page \(page): \(itemsToApply.count) new/updated items")
            
            if response.items.count < perPage { break }
            page += 1
        }
        
        await updateProgress(.finalizing)
        
        await MainActor.run {
            if let maxLastUpdate {
                self.syncState.cursorLastUpdate = maxLastUpdate
            }
        }
        
        debugLog(.sync, "Incremental sync completed: \(totalItemsFetched) items updated, new cursor: \(maxLastUpdate?.description ?? "unchanged")")
    }
    
    // MARK: - Helpers
    
    private func updateProgress(_ phase: SyncProgress.Phase) async {
        await MainActor.run {
            self.progress.phase = phase
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
