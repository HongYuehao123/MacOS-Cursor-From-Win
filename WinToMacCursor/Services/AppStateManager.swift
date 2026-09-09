import AppKit
import Combine
import Foundation

public final class AppStateManager: ObservableObject {
    public static let shared = AppStateManager()

    public static let hideDockIconKey = "WinToMacCursor_HideDockIcon"
    public static let restoreOnQuitKey = "WinToMacCursor_RestoreOnQuit"

    @Published public var hideDockIcon: Bool {
        didSet {
            UserDefaults.standard.set(hideDockIcon, forKey: Self.hideDockIconKey)
            applyActivationPolicy()
        }
    }

    @Published public var restoreOnQuit: Bool {
        didSet {
            UserDefaults.standard.set(restoreOnQuit, forKey: Self.restoreOnQuitKey)
        }
    }

    private init() {
        self.hideDockIcon = UserDefaults.standard.bool(forKey: Self.hideDockIconKey)
        self.restoreOnQuit = UserDefaults.standard.bool(forKey: Self.restoreOnQuitKey)
    }

    @discardableResult
    public func applyActivationPolicy() -> NSApplication.ActivationPolicy {
        let policy: NSApplication.ActivationPolicy = hideDockIcon ? .accessory : .regular
        _ = NSApp.setActivationPolicy(policy)
        if policy == .regular {
            NSApp.activate(ignoringOtherApps: true)
        }
        return policy
    }
}
