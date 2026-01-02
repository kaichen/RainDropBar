//
//  StatusBar.swift
//  RainDropBar
//
//  Created by Kai on 2026-01-02.
//

import SwiftUI
import AppKit

struct StatusBar: View {
    var syncService: SyncService
    let onSettings: () -> Void
    let onSync: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Group {
                if syncService.isSyncing {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text(syncService.progress.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else if let error = syncService.error {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .help(error.localizedDescription)
                } else if let lastSync = syncService.lastSyncTime {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(lastSync, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else {
                    Text("Not synced")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 8) {
                Button {
                    onSync()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(syncService.isSyncing)
                .help("Sync now")
                
                Menu {
                    Button("Settings") {
                        debugLog(.ui, "StatusBar: Settings menu item tapped")
                        DispatchQueue.main.async {
                            debugLog(.ui, "StatusBar: calling onSettings() async")
                            onSettings()
                        }
                    }
                    
                    Button("About") {
                        showAboutAlert()
                    }
                    
                    Divider()
                    
                    Button("Quit") {
                        NSApp.terminate(nil)
                    }
                } label: {
                    Image(systemName: "gearshape")
                }
                .menuStyle(.borderlessButton)
                .help("Settings")
            }
            .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

private extension StatusBar {
    func showAboutAlert() {
        let name = (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? "RainDropBar"
        let version = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "Unknown"
        let build = (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "Unknown"
        
        let alert = NSAlert()
        alert.messageText = "About \(name)"
        alert.informativeText = "Version \(version) (\(build))"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
