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
        let repoURLString = "https://github.com/kaichen/RainDropBar"
        let repoURL = URL(string: repoURLString)
        
        let alert = NSAlert()
        alert.messageText = "About \(name)"
        alert.informativeText = "Version \(version) (\(build))\nRepository: \(repoURLString)"
        alert.alertStyle = .informational
        alert.icon = NSApp.applicationIconImage
        alert.addButton(withTitle: "OK")
        
        if let repoURL {
            alert.accessoryView = makeRepoAccessoryView(repoURL: repoURL, repoURLString: repoURLString)
        }
        
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
    
    func makeRepoAccessoryView(repoURL: URL, repoURLString: String) -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        
        let iconButton = RepoLinkButton(repoURL: repoURL, image: NSApp.applicationIconImage)
        iconButton.toolTip = "在浏览器打开仓库"
        
        let linkButton = RepoLinkButton(repoURL: repoURL, title: repoURLString)
        linkButton.toolTip = "在浏览器打开仓库"
        
        stack.addArrangedSubview(iconButton)
        stack.addArrangedSubview(linkButton)
        return stack
    }
}

private final class RepoLinkButton: NSButton {
    private let repoURL: URL
    
    init(repoURL: URL) {
        self.repoURL = repoURL
        super.init(frame: .zero)
        target = self
        action = #selector(openRepo)
        translatesAutoresizingMaskIntoConstraints = false
    }
    
    convenience init(repoURL: URL, image: NSImage?) {
        self.init(repoURL: repoURL)
        self.image = image
        isBordered = false
        bezelStyle = .shadowlessSquare
        imageScaling = .scaleProportionallyUpOrDown
        setButtonType(.momentaryChange)
        heightAnchor.constraint(equalToConstant: 44).isActive = true
        widthAnchor.constraint(equalTo: heightAnchor).isActive = true
    }
    
    convenience init(repoURL: URL, title: String) {
        self.init(repoURL: repoURL)
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        ]
        attributedTitle = NSAttributedString(string: title, attributes: attributes)
        isBordered = false
        bezelStyle = .recessed
        lineBreakMode = .byTruncatingMiddle
        setButtonType(.momentaryChange)
    }
    
    @objc private func openRepo() {
        NSWorkspace.shared.open(repoURL)
    }
    
    required init?(coder: NSCoder) {
        self.repoURL = URL(string: "https://github.com/kaichen/RainDropBar")!
        super.init(coder: coder)
    }
}
