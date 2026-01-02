import AppKit
@preconcurrency import Settings

final class AppDelegate: NSObject, NSApplicationDelegate {
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
        debugLog(.app, "AppDelegate initialized")
    }
    
    @MainActor
    func showSettings() {
        dismissMenuBarWindows()
        
        DispatchQueue.main.async {
            self.settingsWindowController.show()
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    @MainActor
    private func dismissMenuBarWindows() {
        // MenuBarExtra(.window) 会创建 borderless / popUpMenu 级别的宿主窗口，需要先隐藏以避免挡住 settings。
        for window in NSApp.windows where window.level == .popUpMenu || window.styleMask.contains(.borderless) {
            window.orderOut(nil)
        }
    }
}
