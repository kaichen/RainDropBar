import SwiftUI
import AppKit
import enum Settings.Settings
import protocol Settings.SettingsPane

struct AdvancedSettingsPane: View {
    @State private var logsCopied = false
    @State private var showResyncConfirm = false
    private var syncService = SyncService.shared
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Button("Force Full Resync") {
                            showResyncConfirm = true
                        }
                        .disabled(syncService.isSyncing)
                    }
                    
                    Text("Re-downloads all bookmarks from scratch. Use if sync is out of date.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if syncService.syncState.hasCompletedFullBackfill,
                       let cursor = syncService.syncState.cursorLastUpdate {
                        Text("Cursor: \(cursor, style: .date) \(cursor, style: .time)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            } header: {
                Text("Sync")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Button("Copy Debug Logs") {
                            copyLogs()
                        }
                        
                        Button("Open Log File") {
                            openLogFile()
                        }
                        
                        Button("Clear Logs", role: .destructive) {
                            DebugLogger.shared.clearLogs()
                        }
                    }
                    
                    if logsCopied {
                        Text("Copied to clipboard!")
                            .foregroundStyle(.green)
                            .transition(.opacity)
                    }
                    
                    Text("Log file: \(DebugLogger.shared.logFilePath.path)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                }
            } header: {
                Text("Debug Logs")
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 250)
        .confirmationDialog("Force Full Resync?", isPresented: $showResyncConfirm) {
            Button("Resync All Bookmarks", role: .destructive) {
                Task {
                    await syncService.forceFullResync()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will re-download all bookmarks. This may take a while for large libraries.")
        }
    }
    
    private func copyLogs() {
        let logs = DebugLogger.shared.getLogContents()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(logs, forType: .string)
        logsCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            logsCopied = false
        }
    }
    
    private func openLogFile() {
        let logPath = DebugLogger.shared.logFilePath.path
        NSWorkspace.shared.selectFile(logPath, inFileViewerRootedAtPath: "")
    }
}

func AdvancedSettingsPaneController() -> SettingsPane {
    let paneView = Settings.Pane(
        identifier: .advanced,
        title: "Advanced",
        toolbarIcon: NSImage(systemSymbolName: "wrench.and.screwdriver", accessibilityDescription: "Advanced settings")!
    ) {
        AdvancedSettingsPane()
    }
    return Settings.PaneHostingController(pane: paneView)
}
