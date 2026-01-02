//
//  SettingsView.swift
//  RainDropBar
//
//  Created by Kai on 2026-01-02.
//

import SwiftUI
import AppKit

struct SettingsView: View {
    @State private var token: String = TokenManager.shared.token ?? ""
    @State private var showToken = false
    @State private var saved = false
    @State private var logsCopied = false
    
    var body: some View {
        Form {
            Section {
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
            } header: {
                Text("API Token")
            }
            
            Section {
                HStack {
                    Button("Save") {
                        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
                        TokenManager.shared.token = trimmedToken.isEmpty ? nil : trimmedToken
                        saved = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            saved = false
                        }
                    }
                    .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    
                    Button("Clear Token", role: .destructive) {
                        token = ""
                        TokenManager.shared.token = nil
                        saved = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            saved = false
                        }
                    }
                    .disabled(TokenManager.shared.token == nil)
                }
                
                if saved {
                    Text("Saved!")
                        .foregroundStyle(.green)
                }
            }
            
            Section {
                HStack {
                    Button("Copy Debug Logs") {
                        let logs = DebugLogger.shared.getLogContents()
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(logs, forType: .string)
                        logsCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            logsCopied = false
                        }
                    }
                    
                    Button("Open Log File") {
                        let logPath = DebugLogger.shared.logFilePath.path
                        NSWorkspace.shared.selectFile(logPath, inFileViewerRootedAtPath: "")
                    }
                    
                    Button("Clear Logs", role: .destructive) {
                        DebugLogger.shared.clearLogs()
                    }
                }
                
                if logsCopied {
                    Text("Copied to clipboard!")
                        .foregroundStyle(.green)
                }
                
                Text("Log file: \(DebugLogger.shared.logFilePath.path)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } header: {
                Text("Debug")
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 280)
    }
}

#Preview {
    SettingsView()
}
