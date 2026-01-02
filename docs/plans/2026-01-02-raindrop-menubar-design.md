# RainDropBar - macOS Menubar Client Design

## Overview

A macOS menubar client for Raindrop.io that allows quick viewing and searching of saved bookmarks.

## Core Features

- View recent bookmarks from menubar
- Search bookmarks by title, excerpt, domain, tags
- Click to open in default browser
- Local caching for offline access
- Manual test token authentication

## Architecture

```
┌─────────────────────────────────────────────────┐
│                   RainDropBar                    │
├─────────────────────────────────────────────────┤
│  MenuBarApp                                      │
│  └── MenuBarExtra (系统托盘图标)                  │
│       └── PopoverView                           │
│            ├── SearchField (搜索框)              │
│            └── BookmarkListView (书签列表)       │
├─────────────────────────────────────────────────┤
│  Services                                        │
│  ├── RaindropAPI      (API 请求)                 │
│  ├── TokenManager     (Keychain 存储 token)      │
│  └── SyncService      (后台同步逻辑)              │
├─────────────────────────────────────────────────┤
│  Data (SwiftData)                               │
│  ├── Raindrop         (书签模型)                 │
│  └── Collection       (分类模型)                 │
└─────────────────────────────────────────────────┘
```

## Data Models

Based on [Raindrop.io API](https://developer.raindrop.io/).

### Raindrop

```swift
@Model
final class Raindrop {
    @Attribute(.unique) var id: Int              // API: _id
    var title: String
    var link: String
    var excerpt: String
    var note: String
    var domain: String
    var cover: String                            // cover URL
    var type: String                             // link, article, image, video, document, audio
    var tags: [String]
    var important: Bool                          // favorite
    var collectionID: Int                        // API: collection.$id
    var created: Date
    var lastUpdate: Date
}
```

### Collection

```swift
@Model
final class Collection {
    @Attribute(.unique) var id: Int              // API: _id
    var title: String
    var count: Int
    var cover: String                            // API returns array, take first
    var color: String                            // HEX color
    var parentID: Int?                           // API: parent.$id, nil = root
    var sortOrder: Int                           // API: sort
    var view: String                             // list, simple, grid, masonry
    var isPublic: Bool                           // API: public
    var expanded: Bool
    var lastUpdate: Date
}
```

System Collection IDs: `-1` = Unsorted, `-99` = Trash

## UI Design

```
┌─────────────────────────────────────┐  Width: 320pt, Height: 480pt
│ 🔍 [Search bookmarks...           ] │  SearchField, auto-focus
├─────────────────────────────────────┤
│ ┌─────────────────────────────────┐ │
│ │ 📄 Article Title Here           │ │  Bookmark row
│ │    domain.com · Design          │ │  Subtitle: domain + collection
│ └─────────────────────────────────┘ │
│ ┌─────────────────────────────────┐ │
│ │ ⭐ Important Bookmark           │ │  Star icon for important=true
│ │    github.com · Dev             │ │
│ └─────────────────────────────────┘ │
│              ...                    │
├─────────────────────────────────────┤
│ ⟳ Synced 3 min ago      ⚙️        │  Status bar + settings
└─────────────────────────────────────┘
```

### Interactions

- Click bookmark → open link in default browser
- Cmd+F or open → focus search field
- Search scope: title, excerpt, domain, tags
- Scroll for more (local data, no pagination needed)
- Settings: configure token, manual sync, quit

### Visual Style

- Native macOS style
- Type-specific icons (link/article/image/video/document/audio)
- Auto dark mode support

## API & Sync

### Endpoints

```
GET /rest/v1/collections              # All collections
GET /rest/v1/collections/childrens    # Nested collections
GET /rest/v1/raindrops/0?page=N       # All raindrops (paginated)
GET /rest/v1/raindrops/{id}?page=N    # Raindrops in collection
```

### Sync Strategy

- Full sync on app launch
- Background sync every 15 minutes
- Manual sync from settings
- Upsert based on `lastUpdate` field
- Remove local records not in remote

### Token Storage

- Store test token in Keychain
- Show settings view on first launch if no token

## File Structure

```
RainDropBar/
├── RainDropBarApp.swift          # MenuBarExtra entry
├── Models/
│   ├── Raindrop.swift
│   └── Collection.swift
├── Services/
│   ├── RaindropAPI.swift
│   ├── SyncService.swift
│   └── TokenManager.swift
├── Views/
│   ├── PopoverView.swift
│   ├── SearchField.swift
│   ├── RaindropRow.swift
│   ├── StatusBar.swift
│   └── SettingsView.swift
└── Utilities/
    └── TypeIcon.swift
```

## Implementation Order

1. Convert App entry to MenuBarExtra
2. Define SwiftData models
3. TokenManager - Keychain operations
4. SettingsView - token input UI
5. RaindropAPI - API wrapper
6. SyncService - sync logic
7. Views - UI components
8. Integration testing
