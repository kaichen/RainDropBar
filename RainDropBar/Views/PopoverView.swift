//
//  PopoverView.swift
//  RainDropBar
//
//  Created by Kai on 2026-01-02.
//

import SwiftUI
import SwiftData

struct PopoverView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openSettings) private var openSettings
    
    @Query(sort: \Raindrop.created, order: .reverse) private var raindrops: [Raindrop]
    @Query private var collections: [RaindropCollection]
    
    @State private var syncService = SyncService.shared
    @State private var searchText = ""
    
    private var filteredRaindrops: [Raindrop] {
        if searchText.isEmpty {
            return raindrops
        }
        let query = searchText.lowercased()
        return raindrops.filter { raindrop in
            raindrop.title.lowercased().contains(query) ||
            raindrop.excerpt.lowercased().contains(query) ||
            raindrop.domain.lowercased().contains(query) ||
            raindrop.tags.contains { $0.lowercased().contains(query) }
        }
    }
    
    private var collectionsMap: [Int: String] {
        Dictionary(uniqueKeysWithValues: collections.map { ($0.id, $0.title) })
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search bookmarks...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(12)
            
            Divider()
            
            // Content
            if !TokenManager.shared.hasToken {
                noTokenView
            } else if raindrops.isEmpty && !syncService.isSyncing {
                emptyView
            } else {
                bookmarksList
            }
            
            Divider()
            
            // Status bar
            StatusBar(syncService: syncService, onSettings: {
                openSettings()
            }, onSync: {
                Task {
                    try? await syncService.sync()
                }
            })
        }
        .frame(width: 320, height: 480)
        .onAppear {
            syncService.configure(modelContext: modelContext)
            if TokenManager.shared.hasToken {
                Task {
                    try? await syncService.sync()
                }
                syncService.startAutoSync()
            }
        }
    }
    
    private var noTokenView: some View {
        VStack(spacing: 12) {
            Image(systemName: "key")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No API Token")
                .font(.headline)
            Text("Configure your token in Settings")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Open Settings") {
                openSettings()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No bookmarks")
                .font(.headline)
            Text("Your bookmarks will appear here after syncing")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var bookmarksList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredRaindrops) { raindrop in
                    RaindropRow(
                        raindrop: raindrop,
                        collectionTitle: collectionsMap[raindrop.collectionID]
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    
                    if raindrop.id != filteredRaindrops.last?.id {
                        Divider()
                            .padding(.leading, 42)
                    }
                }
            }
        }
    }
}

#Preview {
    PopoverView()
        .modelContainer(for: [Raindrop.self, RaindropCollection.self], inMemory: true)
}
