//
//  PopoverView.swift
//  RainDropBar
//
//  Created by Kai on 2026-01-02.
//

import SwiftUI
import SwiftData
import AppKit

struct PopoverView: View {
    @Environment(\.modelContext) private var modelContext
    
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
                TextField("search.placeholder", text: $searchText)
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
                debugLog(.ui, "PopoverView: onSettings tapped, NSApp.delegate=\(String(describing: NSApp.delegate)), AppDelegate.shared=\(String(describing: AppDelegate.shared))")
                AppDelegate.shared?.showSettings()
            }, onSync: {
                Task {
                    try? await syncService.sync()
                }
            })
        }
        .frame(width: 320, height: 480)
        .onAppear {
            debugLog(.ui, "PopoverView appeared")
            debugLog(.ui, "Raindrops count: \(raindrops.count), Collections count: \(collections.count)")
        }
    }
    
    private var noTokenView: some View {
        VStack(spacing: 12) {
            Image(systemName: "key")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("noToken.title")
                .font(.headline)
            Text("noToken.subtitle")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("noToken.button") {
                AppDelegate.shared?.showSettings()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("empty.title")
                .font(.headline)
            Text("empty.subtitle")
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
                        collectionTitle: collectionsMap[raindrop.collectionID],
                        onOpen: dismissPopover
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
    
    private func dismissPopover() {
        let popoverWindows = NSApp.windows.filter { $0.level == .popUpMenu || $0.styleMask.contains(.borderless) }
        for window in popoverWindows {
            window.orderOut(nil)
        }
    }
}

#Preview {
    PopoverView()
        .modelContainer(for: [Raindrop.self, RaindropCollection.self], inMemory: true)
}
