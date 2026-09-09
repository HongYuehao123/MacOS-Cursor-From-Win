import SwiftUI
import AppKit

@main
struct WinToMacCursorApp: App {
    // 1. 接管系统级生命周期（用于底层 C/CGEvent 钩子安全释放与还原系统默认状态）
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @ObservedObject private var langManager = LanguageManager.shared
    @StateObject private var cursorManager = SystemCursorManager.shared
    @StateObject private var libraryManager = SchemeLibraryManager.shared
    @StateObject private var appState = AppStateManager.shared

    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        // MARK: - 主窗口 (光标方案库与可视化管理)
        WindowGroup(L10n.tr("app_title"), id: "main") {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1387, height: 897)
        .commands {
            SidebarCommands()
        }

        // MARK: - 偏好设置窗口 (Preferences / Settings Scene)
        Settings {
            SettingsView()
        }

        // MARK: - 顶部菜单栏常驻托盘 (MenuBarExtra)
        MenuBarExtra {
            // 1. 状态指示与全局启用/禁用开关 (Toggle)
            Toggle(isOn: Binding(
                get: { cursorManager.isCustomApplied },
                set: { enabled in
                    if enabled {
                        if let scheme = libraryManager.activeScheme {
                            _ = cursorManager.applyScheme(scheme)
                        }
                    } else {
                        cursorManager.restoreDefaults()
                    }
                }
            )) {
                Text(cursorManager.isCustomApplied
                     ? L10n.tr("menu_status_custom", cursorManager.lastAppliedSchemeName ?? L10n.tr("menu_status_custom_fallback"))
                     : L10n.tr("menu_status_default"))
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])

            Divider()

            // 2. 方案快速切换子菜单 (Schemes)
            Menu(L10n.tr("menu_schemes_header")) {
                if libraryManager.schemes.isEmpty {
                    Text(L10n.tr("menu_empty_schemes"))
                } else {
                    ForEach(libraryManager.schemes) { scheme in
                        Button {
                            selectScheme(scheme)
                        } label: {
                            HStack {
                                if cursorManager.isCustomApplied && (cursorManager.lastAppliedSchemeName == scheme.name) {
                                    Image(systemName: "checkmark")
                                }
                                let typePrefix = scheme.isAnimatedScheme ? L10n.tr("menu_animated_prefix") : L10n.tr("menu_static_prefix")
                                Text("\(typePrefix) \(scheme.name) (\(scheme.items.count))")
                            }
                        }
                    }
                }
            }

            // 3. 还原系统默认指针
            Button(L10n.tr("menu_restore_defaults")) {
                cursorManager.restoreDefaults()
            }
            .keyboardShortcut("r", modifiers: .command)

            Divider()

            // 4. 打开主控制窗口
            Button(L10n.tr("menu_open_main_window")) {
                openMainWindowAction()
            }
            .keyboardShortcut("o", modifiers: .command)

            // 5. 偏好设置入口 (使用 SettingsLink 或向下兼容方案)
            if #available(macOS 14.0, *) {
                SettingsLink {
                    Text(L10n.tr("menu_settings"))
                }
                .keyboardShortcut(",", modifiers: .command)
            } else {
                Button(L10n.tr("menu_settings")) {
                    openSettingsAction()
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            Divider()

            // 6. 退出应用
            Button(L10n.tr("menu_quit")) {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)

        } label: {
            Image(systemName: cursorManager.isCustomApplied ? "cursorarrow.rays" : "cursorarrow")
        }
    }

    private func selectScheme(_ scheme: CursorScheme) {
        if let idx = libraryManager.schemes.firstIndex(where: { $0.id == scheme.id }) {
            libraryManager.selectedSchemeIndex = idx
        }
        _ = cursorManager.applyScheme(scheme)
    }

    private func openMainWindowAction() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { !$0.className.contains("StatusBar") && !$0.className.contains("Panel") && $0.canBecomeKey }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "main")
        }
    }

    private func openSettingsAction() {
        NSApp.activate(ignoringOtherApps: true)
        let success = NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        if !success {
            _ = NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
}

// MARK: - 底层生命周期托管与守卫 (AppDelegate)
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // [底层接入点 1]：根据用户设置应用 Dock 图标显示/隐藏（作为 UIElement 托盘工具）
        AppStateManager.shared.applyActivationPolicy()

        // [底层接入点 2]：初始化底层光标管理与主题库
        _ = SystemCursorManager.shared
        SchemeLibraryManager.shared.bootstrapDefaultThemesIfNeeded()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        if let first = NSApp.windows.first(where: { !$0.className.contains("StatusBar") && !$0.className.contains("Panel") && $0.canBecomeKey }) {
            first.makeKeyAndOrderFront(nil)
        }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        // [底层接入点 3 - 极重要]：退出应用时安全卸载 Hook / 还原原生默认光标，防止系统指针丢失
        if UserDefaults.standard.bool(forKey: AppStateManager.restoreOnQuitKey) {
            SystemCursorManager.shared.restoreDefaults()
        }
    }
}
