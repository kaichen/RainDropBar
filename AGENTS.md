# RAINDROP-BAR PROJECT KNOWLEDGE

**Generated:** 2026-01-02 15:53 | **Commit:** f4bfb0b | **Branch:** main

## OVERVIEW

macOS menubar app syncing bookmarks from Raindrop.io. SwiftUI + SwiftData + Keychain.

## STRUCTURE

```
RainDropBar/
├── RainDropBarApp.swift    # @main entry, ModelContainer init, error recovery
├── Models/
│   ├── Raindrop.swift      # @Model bookmark entity
│   └── Collection.swift    # @Model collection (file ≠ class name)
├── Services/
│   ├── RaindropAPI.swift   # HTTP client + response types (189 LOC)
│   ├── SyncService.swift   # @Observable sync orchestrator (287 LOC)
│   └── TokenManager.swift  # Keychain CRUD (130 LOC)
├── Views/
│   ├── PopoverView.swift   # Main UI, @Query, sync bootstrap
│   ├── StatusBar.swift     # Sync status + error display
│   ├── SettingsView.swift  # Token config
│   ├── RaindropRow.swift   # Bookmark list item
│   └── DatabaseErrorView.swift  # Recovery UI
└── Utilities/
    ├── DebugLogger.swift   # Console + file logging, token redaction
    └── TypeIcon.swift      # SF Symbol mapping
```

## WHERE TO LOOK

| Task | Location |
|------|----------|
| App bootstrap | `RainDropBarApp.swift` |
| API integration | `Services/RaindropAPI.swift` |
| Data sync logic | `Services/SyncService.swift` |
| Token storage | `Services/TokenManager.swift` |
| Main UI | `Views/PopoverView.swift` |
| Data models | `Models/*.swift` |
| Debug logging | `Utilities/DebugLogger.swift` |

## CODE MAP

| Symbol | Type | Role |
|--------|------|------|
| `RainDropBarApp` | struct | @main, ModelContainer setup, error recovery |
| `SyncService` | class | @Observable @MainActor, sync orchestration, auto-sync timer |
| `RaindropAPI` | struct | REST client, response decoding |
| `TokenManager` | class | Singleton, Keychain ops |
| `Raindrop` | class | @Model bookmark entity |
| `RaindropCollection` | class | @Model collection entity |
| `DebugLogger` | class | Singleton, console + file logging |
| `debugLog()` | func | Global convenience for `DebugLogger.shared.log()` |

## CONVENTIONS

- **Architecture**: MVVM-lite. Views use `@Query` directly (acceptable at this scale)
- **Singletons**: `SyncService.shared`, `TokenManager.shared`, `DebugLogger.shared`
- **Error handling**: `syncService.error` property for UI display
- **Keychain**: Update-or-add pattern, not delete-then-add
- **Logging**: Use `debugLog(.category, "message")` with LogCategory enum

## ANTI-PATTERNS

- **NEVER** use `fatalError` for recoverable errors (see DatabaseErrorView pattern)
- **NEVER** mutate SwiftData before all API fetches complete (atomic sync)
- **NEVER** open non-http(s) URLs from remote data
- **NEVER** use `try?` for sync operations without storing error state
- **NEVER** log tokens in plaintext (use `DebugLogger.shared.redactToken()`)

## BUILD & TEST

```bash
# Build
xcodebuild -scheme RainDropBar -destination 'platform=macOS' build

# Test
xcodebuild -scheme RainDropBar test

# Open in Xcode
open RainDropBar.xcodeproj
```

## NOTES

- **File naming quirk**: `Collection.swift` contains `RaindropCollection` class
- **API response**: `RaindropsResponse.count` is optional (API inconsistency)
- **Sync pattern**: Fetch ALL remote data first, THEN apply mutations atomically
- **Auto-sync**: 15min interval via Timer, starts on token presence
- **Sandbox**: App is sandboxed with network + keychain entitlements
- **Log file**: `~/Library/Application Support/RainDropBar/debug.log`
