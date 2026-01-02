//
//  SyncState.swift
//  RainDropBar
//
//  Created by Kai on 2026-01-02.
//

import Foundation

/// Persistent sync metadata stored in UserDefaults
struct SyncState: Codable {
    /// Whether full backfill has been completed at least once
    var hasCompletedFullBackfill: Bool = false
    
    /// High-water mark for incremental sync (max lastUpdate seen)
    var cursorLastUpdate: Date?
    
    /// High-water mark for trash sync
    var trashCursorLastUpdate: Date?
    
    /// Last successful sync completion time
    var lastSuccessfulSyncAt: Date?
    
    /// Last sync attempt time
    var lastAttemptAt: Date?
    
    /// In-progress checkpoint for resume support
    var checkpoint: SyncCheckpoint?
    
    /// Schema version for future migrations
    var syncVersion: Int = 1
    
    static let userDefaultsKey = "SyncState"
    
    static func load() -> SyncState {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            debugLog(.sync, "SyncState: no saved state, returning default")
            return SyncState()
        }
        
        do {
            let state = try JSONDecoder().decode(SyncState.self, from: data)
            debugLog(.sync, "SyncState: loaded (hasFullBackfill=\(state.hasCompletedFullBackfill), cursor=\(state.cursorLastUpdate?.description ?? "nil"))")
            return state
        } catch {
            debugLog(.sync, "SyncState: decode error \(error), returning default")
            return SyncState()
        }
    }
    
    func save() {
        do {
            let data = try JSONEncoder().encode(self)
            UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
            debugLog(.sync, "SyncState: saved (hasFullBackfill=\(hasCompletedFullBackfill), cursor=\(cursorLastUpdate?.description ?? "nil"))")
        } catch {
            debugLog(.sync, "SyncState: save error \(error)")
        }
    }
    
    mutating func reset() {
        self = SyncState()
        save()
        debugLog(.sync, "SyncState: reset to defaults")
    }
}

/// Checkpoint for resuming interrupted sync
struct SyncCheckpoint: Codable {
    enum Mode: String, Codable {
        case fullBackfill
        case incremental
    }
    
    var mode: Mode
    var collectionID: Int?
    var page: Int
    var startedAt: Date
    var itemsProcessed: Int
}

// MARK: - Sync Progress

/// Observable progress state for UI
struct SyncProgress: Equatable {
    enum Phase: Equatable {
        case idle
        case starting
        case fetchingCollections
        case syncingBookmarks
        case syncingTrash
        case finalizing
        case completed
        case cancelled
        case failed
        
        var localizedString: String {
            switch self {
            case .idle: return String(localized: "sync.idle")
            case .starting: return String(localized: "sync.starting")
            case .fetchingCollections: return String(localized: "sync.fetchingCollections")
            case .syncingBookmarks: return String(localized: "sync.syncingBookmarks")
            case .syncingTrash: return String(localized: "sync.syncingTrash")
            case .finalizing: return String(localized: "sync.finalizing")
            case .completed: return String(localized: "sync.completed")
            case .cancelled: return String(localized: "sync.cancelled")
            case .failed: return String(localized: "sync.failed")
            }
        }
    }
    
    var phase: Phase = .idle
    
    /// Overall progress: (completed, total). Total may be nil if unknown.
    var completedUnits: Int = 0
    var totalUnits: Int?
    
    /// Current detail info
    var currentCollectionTitle: String?
    var currentPage: Int?
    var itemsApplied: Int = 0
    
    /// Progress fraction (0.0 to 1.0), nil if indeterminate
    var fractionCompleted: Double? {
        guard let total = totalUnits, total > 0 else { return nil }
        let fraction = Double(completedUnits) / Double(total)
        return min(max(fraction, 0), 1)
    }
    
    /// Whether progress is indeterminate (unknown total)
    var isIndeterminate: Bool {
        totalUnits == nil
    }
    
    /// Human-readable status message
    var message: String {
        switch phase {
        case .idle, .starting, .fetchingCollections, .finalizing, .completed, .cancelled, .failed:
            return phase.localizedString
        case .syncingBookmarks, .syncingTrash:
            var msg = phase.localizedString
            if let title = currentCollectionTitle {
                msg += " \(title)"
            }
            if let page = currentPage {
                let pageStr = String(format: NSLocalizedString("sync.page", comment: ""), page + 1)
                msg += " (\(pageStr))"
            }
            if itemsApplied > 0 {
                let itemsStr = String(format: NSLocalizedString("sync.items", comment: ""), itemsApplied)
                msg += " - \(itemsStr)"
            }
            return msg
        }
    }
    
    static let idle = SyncProgress()
}

// MARK: - Sync Mode

enum SyncMode {
    case fullBackfill
    case incremental
    case forceFullResync
}
