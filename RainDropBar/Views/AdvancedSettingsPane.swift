import SwiftUI
import AppKit
import enum Settings.Settings
import protocol Settings.SettingsPane

struct AdvancedSettingsPane: View {
    @State private var logsCopied = false
    @State private var showResyncConfirm = false
    private var syncService = SyncService.shared
    
    var body: some View {
        Settings.Container(contentWidth: 450.0) {
            Settings.Section(title: String(localized: "settings.sync")) {
                VStack(alignment: .leading, spacing: 10) {
                    Button("settings.forceResync") {
                        showResyncConfirm = true
                    }
                    .disabled(syncService.isSyncing)
                    
                    Text("settings.forceResync.help")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if syncService.syncState.hasCompletedFullBackfill,
                       let cursor = syncService.syncState.cursorLastUpdate {
                        Text("settings.cursor \(cursor, style: .date) \(cursor, style: .time)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            
            Settings.Section(title: String(localized: "settings.debugLogs")) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Button("settings.copyLogs") {
                            copyLogs()
                        }
                        
                        Button("settings.openLogFile") {
                            openLogFile()
                        }
                        
                        Button("settings.clearLogs", role: .destructive) {
                            DebugLogger.shared.clearLogs()
                        }
                    }
                    
                    if logsCopied {
                        Text("settings.logsCopied")
                            .foregroundStyle(.green)
                            .transition(.opacity)
                    }
                    
                    Text("settings.logFile \(DebugLogger.shared.logFilePath.path)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                }
            }
        }
        .frame(minHeight: 220)
        .confirmationDialog(String(localized: "dialog.resync.title"), isPresented: $showResyncConfirm) {
            Button("dialog.resync.button", role: .destructive) {
                Task {
                    await syncService.forceFullResync()
                }
            }
            Button("settings.cancel", role: .cancel) {}
        } message: {
            Text("dialog.resync.message")
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
        title: String(localized: "settings.advanced"),
        toolbarIcon: NSImage(systemSymbolName: "wrench.and.screwdriver", accessibilityDescription: String(localized: "settings.advanced.accessibility"))!
    ) {
        AdvancedSettingsPane()
    }
    return Settings.PaneHostingController(pane: paneView)
}
