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
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Raindrop.self,
            RaindropCollection.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        MenuBarExtra("RainDropBar", systemImage: "drop.fill") {
            PopoverView()
                .modelContainer(sharedModelContainer)
        }
        .menuBarExtraStyle(.window)
        
        Settings {
            SettingsView()
        }
    }
}
