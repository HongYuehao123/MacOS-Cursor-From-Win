import SwiftUI

@main
struct WinToMacCursorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup("WinToMacCursor - Windows 光标转换与管理器") {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            SidebarCommands()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        StatusBarManager.shared.setup()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        StatusBarManager.shared.showMainWindow()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        if UserDefaults.standard.bool(forKey: "WinToMacCursor_RestoreOnQuit") {
            SystemCursorManager.shared.restoreDefaults()
        }
    }
}
