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
            button.toolTip = L10n.tr("status_bar_tooltip")
        }

        menu.delegate = self
        item.menu = menu
        self.statusItem = item
    }

    // MARK: - NSMenuDelegate (Dynamic Menu Construction)

    public func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if let button = statusItem?.button {
            button.toolTip = L10n.tr("status_bar_tooltip")
        }

        let cursorManager = SystemCursorManager.shared
        let libraryManager = SchemeLibraryManager.shared
        let isCustom = cursorManager.isCustomApplied
        let currentSchemeName = cursorManager.lastAppliedSchemeName

        // 1. Status Header
        let statusTitle = isCustom
            ? L10n.tr("menu_status_custom", currentSchemeName ?? L10n.tr("menu_status_custom_fallback"))
            : L10n.tr("menu_status_default")
        let statusItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

        // 2. Section Header: Schemes
        let schemesHeader = NSMenuItem(title: L10n.tr("menu_schemes_header"), action: nil, keyEquivalent: "")
        schemesHeader.isEnabled = false
        menu.addItem(schemesHeader)

        let schemes = libraryManager.schemes
        if schemes.isEmpty {
            let emptyItem = NSMenuItem(title: L10n.tr("menu_empty_schemes"), action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for scheme in schemes {
                let isCurrent = isCustom && (currentSchemeName == scheme.name)
                let typePrefix = scheme.isAnimatedScheme ? L10n.tr("menu_animated_prefix") : L10n.tr("menu_static_prefix")
                var cleanName = scheme.name
                if cleanName.hasPrefix("[Static]") {
                    cleanName = String(cleanName.dropFirst("[Static]".count)).trimmingCharacters(in: .whitespaces)
                } else if cleanName.hasPrefix("[Animated]") {
                    cleanName = String(cleanName.dropFirst("[Animated]".count)).trimmingCharacters(in: .whitespaces)
                }
                let itemTitle = L10n.tr("menu_scheme_item", typePrefix, cleanName, scheme.items.count)

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
            title: L10n.tr("menu_restore_defaults"),
            action: #selector(restoreDefaultsClicked(_:)),
            keyEquivalent: "r"
        )
        restoreItem.keyEquivalentModifierMask = [.command]
        restoreItem.target = self
        menu.addItem(restoreItem)

        menu.addItem(NSMenuItem.separator())

        // 4. Open Main Window
        let openWindowItem = NSMenuItem(
            title: L10n.tr("menu_open_main_window"),
            action: #selector(openMainWindowClicked(_:)),
            keyEquivalent: "o"
        )
        openWindowItem.keyEquivalentModifierMask = [.command]
        openWindowItem.target = self
        menu.addItem(openWindowItem)

        // 5. Settings Window
        let settingsItem = NSMenuItem(
            title: L10n.tr("menu_settings"),
            action: #selector(openSettingsClicked(_:)),
            keyEquivalent: ","
        )
        settingsItem.keyEquivalentModifierMask = [.command]
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // 6. Quit App
        let quitItem = NSMenuItem(
            title: L10n.tr("menu_quit"),
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

    @objc public func openSettingsClicked(_ sender: Any?) {
        showSettings()
    }

    @objc private func quitAppClicked(_ sender: NSMenuItem) {
        NSApp.terminate(nil)
    }

    public func showSettings() {
        NSApp.activate(ignoringOtherApps: true)
        let success = NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        if !success {
            _ = NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
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
