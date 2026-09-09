import SwiftUI
import AppKit

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

        MenuBarExtra {
            MenuBarContent()
        } label: {
            Image(systemName: "cursorarrow")
        }
    }
}

struct SchemeMenuItem: View {
    @ObservedObject var scheme: CursorScheme
    let isCurrent: Bool
    let action: () -> Void

    var body: some View {
        let typePrefix = scheme.isAnimatedScheme ? L10n.tr("menu_animated_prefix") : L10n.tr("menu_static_prefix")
        let cleanName: String = {
            var name = scheme.name
            if name.hasPrefix("[Static]") {
                name = String(name.dropFirst("[Static]".count)).trimmingCharacters(in: .whitespaces)
            } else if name.hasPrefix("[Animated]") {
                name = String(name.dropFirst("[Animated]".count)).trimmingCharacters(in: .whitespaces)
            }
            return name
        }()
        let itemTitle = L10n.tr("menu_scheme_item", typePrefix, cleanName, scheme.items.count)

        Button(action: action) {
            HStack {
                if isCurrent {
                    Image(systemName: "checkmark")
                }
                Text(itemTitle)
            }
        }
    }
}

struct MenuBarContent: View {
    @StateObject private var cursorManager = SystemCursorManager.shared
    @StateObject private var libraryManager = SchemeLibraryManager.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        // 1. Status Header
        statusHeaderView
        
        Divider()
        
        // 2. Section Header: Schemes
        Button(L10n.tr("menu_schemes_header")) {}
            .disabled(true)
        
        schemesSectionView
        
        Divider()
        
        // 3. Restore Defaults Action
        Button(L10n.tr("menu_restore_defaults")) {
            SystemCursorManager.shared.restoreDefaults()
        }
        .keyboardShortcut("r", modifiers: .command)
        
        Divider()
        
        // 4. Open Main Window
        Button(L10n.tr("menu_open_main_window")) {
            NSApp.activate(ignoringOtherApps: true)
            if let window = NSApp.windows.first(where: { !$0.className.contains("StatusBar") && !$0.className.contains("Panel") && $0.canBecomeKey }) {
                window.makeKeyAndOrderFront(nil)
            } else {
                openWindow(id: "main")
            }
        }
        .keyboardShortcut("o", modifiers: .command)
        
        // 5. Settings Window
        Button(L10n.tr("menu_settings")) {
            NSApp.activate(ignoringOtherApps: true)
            let success = NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            if !success {
                _ = NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
            }
        }
        .keyboardShortcut(",", modifiers: .command)
        
        Divider()
        
        // 6. Quit App
        Button(L10n.tr("menu_quit")) {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }

    @ViewBuilder
    private var statusHeaderView: some View {
        let currentSchemeName = cursorManager.lastAppliedSchemeName
        let statusTitle = cursorManager.isCustomApplied
            ? L10n.tr("menu_status_custom", currentSchemeName ?? L10n.tr("menu_status_custom_fallback"))
            : L10n.tr("menu_status_default")
        
        Button(statusTitle) {}
            .disabled(true)
    }

    @ViewBuilder
    private var schemesSectionView: some View {
        let currentSchemeName = cursorManager.lastAppliedSchemeName
        let schemes = libraryManager.schemes
        
        if schemes.isEmpty {
            Button(L10n.tr("menu_empty_schemes")) {}
                .disabled(true)
        } else {
            ForEach(schemes) { scheme in
                let isCurrent = cursorManager.isCustomApplied && (currentSchemeName == scheme.name)
                SchemeMenuItem(scheme: scheme, isCurrent: isCurrent) {
                    selectScheme(scheme)
                }
            }
        }
    }
    
    private func selectScheme(_ scheme: CursorScheme) {
        if let idx = libraryManager.schemes.firstIndex(where: { $0.id == scheme.id }) {
            libraryManager.selectedSchemeIndex = idx
        }
        let _ = SystemCursorManager.shared.applyScheme(scheme)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppStateManager.shared.applyActivationPolicy()
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        if let first = NSApp.windows.first(where: { !$0.className.contains("StatusBar") && !$0.className.contains("Panel") && $0.canBecomeKey }) {
            first.makeKeyAndOrderFront(nil)
        }
        return true
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        if UserDefaults.standard.bool(forKey: AppStateManager.restoreOnQuitKey) {
            SystemCursorManager.shared.restoreDefaults()
        }
    }
}