import AppKit
import Foundation

public final class StatusBarManager: NSObject, NSMenuDelegate {
    public static let shared = StatusBarManager()

    private var statusItem: NSStatusItem?
    private let menu = NSMenu()

    private override init() {
        super.init()
    }

    public func setup() {
        guard statusItem == nil else { return }

        // Create status bar item in macOS menu bar
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            if let image = NSImage(systemSymbolName: "cursorarrow.motionlines", accessibilityDescription: "WinToMacCursor") {
                image.isTemplate = true
                button.image = image
            } else if let image = NSImage(systemSymbolName: "cursorarrow", accessibilityDescription: "WinToMacCursor") {
                image.isTemplate = true
                button.image = image
            }
            button.toolTip = "WinToMacCursor - 鼠标方案快速切换"
        }

        menu.delegate = self
        item.menu = menu
        self.statusItem = item
    }

    // MARK: - NSMenuDelegate (Dynamic Menu Construction)

    public func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let cursorManager = SystemCursorManager.shared
        let libraryManager = SchemeLibraryManager.shared
        let isCustom = cursorManager.isCustomApplied
        let currentSchemeName = cursorManager.lastAppliedSchemeName

        // 1. Status Header
        let statusTitle = isCustom
            ? "● 当前光标: \(currentSchemeName ?? "已自定义")"
            : "○ 当前光标: 系统默认"
        let statusItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

        // 2. Section Header: Schemes
        let schemesHeader = NSMenuItem(title: "快速切换光标方案:", action: nil, keyEquivalent: "")
        schemesHeader.isEnabled = false
        menu.addItem(schemesHeader)

        let schemes = libraryManager.schemes
        if schemes.isEmpty {
            let emptyItem = NSMenuItem(title: "  (方案库暂无方案，请打开主窗口导入)", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for scheme in schemes {
                let isCurrent = isCustom && (currentSchemeName == scheme.name)
                let typePrefix = scheme.isAnimatedScheme ? "✨ [动态]" : "🖱️ [静态]"
                let itemTitle = "\(typePrefix) \(scheme.name) (\(scheme.items.count)项)"

                let menuItem = NSMenuItem(title: itemTitle, action: #selector(schemeMenuItemClicked(_:)), keyEquivalent: "")
                menuItem.target = self
                menuItem.representedObject = scheme
                menuItem.state = isCurrent ? .on : .off
                menu.addItem(menuItem)
            }
        }

        menu.addItem(NSMenuItem.separator())

        // 3. Restore Defaults Action
        let restoreItem = NSMenuItem(
            title: "↺ 一键恢复系统默认",
            action: #selector(restoreDefaultsClicked(_:)),
            keyEquivalent: "r"
        )
        restoreItem.keyEquivalentModifierMask = [.command]
        restoreItem.target = self
        menu.addItem(restoreItem)

        menu.addItem(NSMenuItem.separator())

        // 4. Open Main Window
        let openWindowItem = NSMenuItem(
            title: "🪟 打开主窗口...",
            action: #selector(openMainWindowClicked(_:)),
            keyEquivalent: "o"
        )
        openWindowItem.keyEquivalentModifierMask = [.command]
        openWindowItem.target = self
        menu.addItem(openWindowItem)

        // 5. Quit App
        let quitItem = NSMenuItem(
            title: "🚪 退出 WinToMacCursor",
            action: #selector(quitAppClicked(_:)),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self
        menu.addItem(quitItem)
    }

    // MARK: - Actions

    @objc private func schemeMenuItemClicked(_ sender: NSMenuItem) {
        guard let scheme = sender.representedObject as? CursorScheme else { return }

        // Synchronize selected index in library
        if let idx = SchemeLibraryManager.shared.schemes.firstIndex(where: { $0.name == scheme.name }) {
            SchemeLibraryManager.shared.selectedSchemeIndex = idx
        }

        // Apply selected scheme globally
        let (success, total) = SystemCursorManager.shared.applyScheme(scheme)
        if success > 0 {
            NSLog("[StatusBarManager] Successfully applied scheme: %@ (%d/%d)", scheme.name, success, total)
        } else {
            NSLog("[StatusBarManager] Failed to apply scheme: %@", scheme.name)
        }
    }

    @objc private func restoreDefaultsClicked(_ sender: NSMenuItem) {
        let ok = SystemCursorManager.shared.restoreDefaults()
        NSLog("[StatusBarManager] Restored defaults: %d", ok ? 1 : 0)
    }

    @objc public func openMainWindowClicked(_ sender: Any?) {
        showMainWindow()
    }

    @objc private func quitAppClicked(_ sender: NSMenuItem) {
        NSApp.terminate(nil)
    }

    public func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)

        // Find primary content window
        for window in NSApp.windows {
            // Ignore status bar window or special utility panels
            let className = String(describing: type(of: window))
            if !className.contains("StatusBar") && !className.contains("Panel") && window.canBecomeKey {
                window.makeKeyAndOrderFront(nil)
                return
            }
        }

        // If closed or unmapped, order front any window
        if let first = NSApp.windows.first(where: { $0.canBecomeKey }) {
            first.makeKeyAndOrderFront(nil)
        }
    }
}
