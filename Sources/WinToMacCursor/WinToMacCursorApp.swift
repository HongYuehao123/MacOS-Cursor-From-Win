import SwiftUI

@main
struct WinToMacCursorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var langManager = LanguageManager.shared

    var body: some Scene {
        WindowGroup(L10n.tr("app_title"), id: "main") {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1387, height: 897)
        .commands {
            SidebarCommands()
        }
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        StatusBarManager.shared.setup()
        AppStateManager.shared.applyActivationPolicy()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        StatusBarManager.shared.showMainWindow()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        if UserDefaults.standard.bool(forKey: AppStateManager.restoreOnQuitKey) {
            SystemCursorManager.shared.restoreDefaults()
        }
    }
}
