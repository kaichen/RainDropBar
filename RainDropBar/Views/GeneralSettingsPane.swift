import SwiftUI
import AppKit
import enum Settings.Settings
import protocol Settings.SettingsPane

struct GeneralSettingsPane: View {
    @State private var token: String = TokenManager.shared.token ?? ""
    @State private var showToken = false
    @State private var saved = false
    private var syncService = SyncService.shared
    
    var body: some View {
        Settings.Container(contentWidth: 450.0) {
            Settings.Section(title: "API Token") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        if showToken {
                            TextField("Test Token", text: $token)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("Test Token", text: $token)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        Button {
                            showToken.toggle()
                        } label: {
                            Image(systemName: showToken ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                    }
                    
                    Text("Get your test token from [raindrop.io/settings/integrations](https://app.raindrop.io/settings/integrations)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Button("Save") {
                            saveToken()
                        }
                        .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        
                        Button("Clear Token", role: .destructive) {
                            clearToken()
                        }
                        .disabled(TokenManager.shared.token == nil)
                        
                        if saved {
                            Text("Saved!")
                                .foregroundStyle(.green)
                                .transition(.opacity)
                        }
                    }
                }
            }
            
            Settings.Section(title: "Sync") {
                SyncProgressView()
            }
        }
        // Protect against edge cases where the initial fittingSize becomes too small (for example, when
        // the Sync section has minimal content). The window can still grow when content requires it.
        .frame(minHeight: 260)
    }
    
    private func saveToken() {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        TokenManager.shared.token = trimmedToken.isEmpty ? nil : trimmedToken
        showSavedFeedback()
    }
    
    private func clearToken() {
        token = ""
        TokenManager.shared.token = nil
        showSavedFeedback()
    }
    
    private func showSavedFeedback() {
        saved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            saved = false
        }
    }
}

struct SyncProgressView: View {
    private var syncService = SyncService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if syncService.isSyncing {
                    if let fraction = syncService.progress.fractionCompleted {
                        ProgressView(value: fraction)
                            .progressViewStyle(.linear)
                    } else {
                        ProgressView()
                            .progressViewStyle(.linear)
                    }
                } else {
                    if let lastSync = syncService.lastSyncTime {
                        Text("Last sync: \(lastSync, style: .relative) ago")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Never synced")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            if syncService.isSyncing {
                Text(syncService.progress.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if let error = syncService.error {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            
            HStack {
                Button("Sync Now") {
                    Task {
                        await syncService.sync()
                    }
                }
                .disabled(syncService.isSyncing || TokenManager.shared.token == nil)
                
                if syncService.canCancel {
                    Button("Cancel") {
                        syncService.cancelSync()
                    }
                }
            }
        }
    }
}

extension Settings.PaneIdentifier {
    static let general = Self("general")
    static let advanced = Self("advanced")
}

func GeneralSettingsPaneController() -> SettingsPane {
    let paneView = Settings.Pane(
        identifier: .general,
        title: "General",
        toolbarIcon: NSImage(systemSymbolName: "gearshape", accessibilityDescription: "General settings")!
    ) {
        GeneralSettingsPane()
    }
    return Settings.PaneHostingController(pane: paneView)
}
