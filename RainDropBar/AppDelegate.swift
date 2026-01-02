import AppKit
@preconcurrency import Settings

final class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate?
    
    private lazy var settingsWindowController = SettingsWindowController(
        panes: [
            GeneralSettingsPaneController(),
            AdvancedSettingsPaneController()
        ],
        style: .toolbarItems,
        animated: true,
        hidesToolbarForSingleItem: true
    )
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        debugLog(.app, "AppDelegate initialized")
    }
    
    @MainActor
    func showSettings() {
        debugLog(.ui, "showSettings invoked from menubar")
        dismissMenuBarWindows()
        
        DispatchQueue.main.async {
            debugLog(.ui, "showSettings presenting SettingsWindowController")
            self.settingsWindowController.show()
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    @MainActor
    private func dismissMenuBarWindows() {
        // MenuBarExtra(.window) 会创建 borderless / popUpMenu 级别的宿主窗口，需要先隐藏以避免挡住 settings。
        let candidates = NSApp.windows.filter { $0.level == .popUpMenu || $0.styleMask.contains(.borderless) }
        debugLog(.ui, "dismissMenuBarWindows candidates count: \(candidates.count)")
        
        for window in candidates {
            debugLog(.ui, "dismissing window: \(window) level=\(window.level.rawValue) style=\(window.styleMask)")
            window.orderOut(nil)
        }
    }
}
