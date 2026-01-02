//
//  RainDropBarApp.swift
//  RainDropBar
//
//  Created by Kai on 2026-01-02.
//

import SwiftUI
import SwiftData

@main
struct RainDropBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    private var sharedModelContainer: ModelContainer? = {
        debugLog(.app, "RainDropBar launching")
        
        let schema = Schema([
            Raindrop.self,
            RaindropCollection.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            let dbURL = URL.applicationSupportDirectory.appending(path: "default.store")
            debugLog(.swiftdata, "Database URL: \(dbURL.path)")
            
            if FileManager.default.fileExists(atPath: dbURL.path) {
                if let attrs = try? FileManager.default.attributesOfItem(atPath: dbURL.path) {
                    let size = attrs[.size] as? Int64 ?? 0
                    let modDate = attrs[.modificationDate] as? Date ?? Date()
                    debugLog(.swiftdata, "Database exists - size: \(size) bytes, modified: \(modDate)")
                }
            } else {
                debugLog(.swiftdata, "Database file does not exist yet (will be created)")
            }
            
            debugLog(.swiftdata, "ModelContainer created successfully")
            
            SyncService.shared.configure(modelContainer: container)
            SyncService.shared.startOnLaunchIfPossible()
            
            return container
        } catch {
            debugLog(.swiftdata, "ModelContainer creation failed: \(error.localizedDescription)")
            return nil
        }
    }()

    var body: some Scene {
        MenuBarExtra("RainDropBar", systemImage: "drop.fill") {
            if let container = sharedModelContainer {
                PopoverView()
                    .modelContainer(container)
            } else {
                DatabaseErrorView(onReset: resetDatabase)
            }
        }
        .menuBarExtraStyle(.window)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    appDelegate.showSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
    
    private func resetDatabase() {
        debugLog(.app, "resetDatabase called")
        let url = URL.applicationSupportDirectory
            .appending(path: "default.store")
        debugLog(.swiftdata, "Removing database at: \(url.path)")
        try? FileManager.default.removeItem(at: url)
        
        let alert = NSAlert()
        alert.messageText = "Database Reset"
        alert.informativeText = "Please restart the app to complete the reset."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Quit")
        alert.runModal()
        NSApp.terminate(nil)
    }
}
