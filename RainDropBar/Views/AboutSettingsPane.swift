import SwiftUI
import AppKit
import enum Settings.Settings
import protocol Settings.SettingsPane

struct AboutSettingsPane: View {
    private let name = (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? "RainDropBar"
    private let version = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "Unknown"
    private let build = (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "Unknown"
    private let repoURLString = "https://github.com/kaichen/RainDropBar"
    private let repoURL = URL(string: "https://github.com/kaichen/RainDropBar")!
    
    var body: some View {
        Settings.Container(contentWidth: 450.0) {
            Settings.Section(title: "") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(nsImage: NSApp.applicationIconImage)
                            .resizable()
                            .frame(width: 64, height: 64)
                            .cornerRadius(12)
                            .shadow(radius: 2, y: 1)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(name)
                                .font(.title3.weight(.semibold))
                            Text("about.version \(version) \(build)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Link(destination: repoURL) {
                        Text(repoURLString)
                            .underline()
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "about.openRepo"))
                }
                .padding(.vertical, 4)
            }
        }
        .frame(minHeight: 180)
    }
}

func AboutSettingsPaneController() -> SettingsPane {
    let paneView = Settings.Pane(
        identifier: .about,
        title: String(localized: "settings.about"),
        toolbarIcon: NSImage(systemSymbolName: "info.circle", accessibilityDescription: String(localized: "settings.about.accessibility"))!
    ) {
        AboutSettingsPane()
    }
    return Settings.PaneHostingController(pane: paneView)
}
