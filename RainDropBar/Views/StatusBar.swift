//
//  StatusBar.swift
//  RainDropBar
//
//  Created by Kai on 2026-01-02.
//

import SwiftUI

struct StatusBar: View {
    var syncService: SyncService
    let onSettings: () -> Void
    let onSync: () -> Void
    
    var body: some View {
        HStack {
            if syncService.isSyncing {
                ProgressView()
                    .scaleEffect(0.6)
                if let progress = syncService.syncProgress {
                    Text(progress)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Syncing...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if syncService.isBackgroundSyncing {
                Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .symbolEffect(.pulse)
                Text("Loading more...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let error = syncService.error {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .help(error.localizedDescription)
            } else if let lastSync = syncService.lastSyncTime {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(lastSync, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Not synced")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button {
                onSync()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(syncService.isSyncing)
            .help("Sync now")
            
            Button {
                onSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
