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
            Settings.Section(title: String(localized: "settings.apiToken")) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        if showToken {
                            TextField("settings.apiToken.placeholder", text: $token)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("settings.apiToken.placeholder", text: $token)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        Button {
                            showToken.toggle()
                        } label: {
                            Image(systemName: showToken ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                    }
                    
                    Text("settings.apiToken.help")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Button("settings.save") {
                            saveToken()
                        }
                        .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        
                        Button("settings.clearToken", role: .destructive) {
                            clearToken()
                        }
                        .disabled(TokenManager.shared.token == nil)
                        
                        if saved {
                            Text("settings.saved")
                                .foregroundStyle(.green)
                                .transition(.opacity)
                        }
                    }
                }
            }
            
            Settings.Section(title: String(localized: "settings.sync")) {
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
                        Text("settings.lastSync \(lastSync, style: .relative)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("settings.neverSynced")
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
                Button("settings.syncNow") {
                    Task {
                        await syncService.sync()
                    }
                }
                .disabled(syncService.isSyncing || TokenManager.shared.token == nil)
                
                if syncService.canCancel {
                    Button("settings.cancel") {
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
    static let about = Self("about")
}

func GeneralSettingsPaneController() -> SettingsPane {
    let paneView = Settings.Pane(
        identifier: .general,
        title: String(localized: "settings.general"),
        toolbarIcon: NSImage(systemSymbolName: "gearshape", accessibilityDescription: String(localized: "settings.general.accessibility"))!
    ) {
        GeneralSettingsPane()
    }
    return Settings.PaneHostingController(pane: paneView)
}
