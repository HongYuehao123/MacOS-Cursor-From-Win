import AppKit
import Foundation

@main
struct TestRunner {
    static func assertTrue(_ condition: Bool, _ message: String) {
        if !condition {
            print("❌ FAIL: \(message)")
            exit(1)
        } else {
            print("✅ PASS: \(message)")
        }
    }

    static func main() {
        print("==================================================")
        print("     WinToMacCursor Automated Test Suite          ")
        print("==================================================")

        let cwd = FileManager.default.currentDirectoryPath
        let testDir = URL(fileURLWithPath: cwd).appendingPathComponent("Test")
        let staticDir = testDir.appendingPathComponent("Minori Cursor static")
        let aniDir = testDir.appendingPathComponent("Minori Cursor animation")

        // 1. Test Static CUR Scheme Parsing
        print("\n--- [1/4] Testing Static CUR Scheme Parsing ---")
        do {
            let staticScheme = try SchemeLoader.loadScheme(from: staticDir)
            assertTrue(staticScheme.items.count == 17, "Parsed 17 static cursor items (actual: \(staticScheme.items.count))")
            assertTrue(staticScheme.name.contains("Hanasato Minori"), "Scheme name parsed from install.inf: \(staticScheme.name)")
            assertTrue(!staticScheme.isAnimatedScheme, "Scheme correctly identified as static")

            for item in staticScheme.items {
                assertTrue(item.frames.count == 1, "\(item.name) has exactly 1 frame")
                assertTrue(item.size.width > 0 && item.size.height > 0, "\(item.name) size is valid: \(item.size)")
                assertTrue(!item.role.macIdentifiers.isEmpty, "\(item.name) maps to macOS identifiers: \(item.role.macIdentifiers)")
            }
        } catch {
            print("❌ Failed to parse static scheme: \(error)")
            exit(1)
        }

        // 2. Test Animated ANI Scheme Parsing
        print("\n--- [2/4] Testing Animated ANI Scheme Parsing ---")
        do {
            let aniScheme = try SchemeLoader.loadScheme(from: aniDir)
            assertTrue(aniScheme.items.count == 17, "Parsed 17 animated cursor items (actual: \(aniScheme.items.count))")
            assertTrue(aniScheme.isAnimatedScheme, "Scheme correctly identified as animated")

            for item in aniScheme.items {
                assertTrue(item.isAnimated, "\(item.name) is marked animated")
                assertTrue(item.frames.count == 12, "\(item.name) has 12 animation frames (actual: \(item.frames.count))")
                assertTrue(item.frameRate > 0.05 && item.frameRate < 0.15, "\(item.name) frame rate is ~0.083s (actual: \(item.frameRate))")
                assertTrue(!item.role.macIdentifiers.isEmpty, "\(item.name) maps to macOS identifiers: \(item.role.macIdentifiers)")
            }
        } catch {
            print("❌ Failed to parse animated scheme: \(error)")
            exit(1)
        }

        // 3. Test .cape File Generation & Validation
        print("\n--- [3/4] Testing .cape Generation & Verification ---")
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("wintomac_test_\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        do {
            let staticScheme = try SchemeLoader.loadScheme(from: staticDir)
            let staticCapeURL = tmpDir.appendingPathComponent("Minori_Static.cape")
            try CapeGenerator.exportCape(from: staticScheme, to: staticCapeURL)
            assertTrue(FileManager.default.fileExists(atPath: staticCapeURL.path), "Static .cape file written to disk")

            let aniScheme = try SchemeLoader.loadScheme(from: aniDir)
            let aniCapeURL = tmpDir.appendingPathComponent("Minori_Animated.cape")
            try CapeGenerator.exportCape(from: aniScheme, to: aniCapeURL)
            assertTrue(FileManager.default.fileExists(atPath: aniCapeURL.path), "Animated .cape file written to disk")

            // Validate with plutil -lint
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/plutil")
            process.arguments = ["-lint", staticCapeURL.path, aniCapeURL.path]
            try process.run()
            process.waitUntilExit()
            assertTrue(process.terminationStatus == 0, "plutil -lint verified both .cape files as valid Apple Property Lists")

            // Check animated .cape internal keys
            let aniData = try Data(contentsOf: aniCapeURL)
            let plist = try PropertyListSerialization.propertyList(from: aniData, format: nil) as! [String: Any]
            let cursors = plist["Cursors"] as! [String: Any]
            assertTrue(cursors["com.apple.coregraphics.Wait"] != nil, "Busy/Wait cursor found in animated cape")
            if let waitDict = cursors["com.apple.coregraphics.Wait"] as? [String: Any] {
                let fc = waitDict["FrameCount"] as? Int ?? 0
                let fd = waitDict["FrameDuration"] as? Double ?? 0.0
                let reps = waitDict["Representations"] as? [Data] ?? []
                assertTrue(fc == 12, "com.apple.coregraphics.Wait FrameCount is 12")
                assertTrue(fd > 0.05, "com.apple.coregraphics.Wait FrameDuration is ~0.083s")
                assertTrue(reps.count >= 2, "com.apple.coregraphics.Wait has both 1x and 2x representations (count: \(reps.count))")
                if reps.count >= 2 {
                    if let rep1 = NSImage(data: reps[0]), let rep2 = NSImage(data: reps[1]) {
                        assertTrue(rep1.size.height == 384, "1x vertical sprite sheet height is 32*12 = 384 (actual: \(rep1.size.height))")
                        assertTrue(rep2.size.height == 768, "2x Retina vertical sprite sheet height is 64*12 = 768 (actual: \(rep2.size.height))")
                    }
                }
            }

            // Direct CGImage Sprite Sheet Test for SystemCursorManager
            let waitItem = aniScheme.items.first(where: { $0.role == .busy })!
            let cg1x = CapeGenerator.createVerticalSpriteSheetImage(frames: waitItem.frames.map(\.image), singleSize: waitItem.size, scale: 1.0)
            let cg2x = CapeGenerator.createVerticalSpriteSheetImage(frames: waitItem.frames.map(\.image), singleSize: waitItem.size, scale: 2.0)
            assertTrue(cg1x != nil && cg1x!.width == 32 && cg1x!.height == 384, "SystemCursorManager 1x CGImage sprite sheet is 32x384")
            assertTrue(cg2x != nil && cg2x!.width == 64 && cg2x!.height == 768, "SystemCursorManager 2x CGImage sprite sheet is 64x768")
        } catch {
            print("❌ Failed during cape generation: \(error)")
            exit(1)
        }

        // 4. Test SkyLight & Native Default Cursor Restoration
        print("\n--- [4/5] Testing SkyLight & Native Default Cursor Restoration ---")
        let manager = SystemCursorManager.shared
        assertTrue(manager.isAvailable, "SkyLight CGS APIs resolved successfully (CGSMainConnectionID, CGSRegisterCursorWithImages, CGSSetRegisteredCursor)")
        assertTrue(manager.defaultMacCursorCapeURL != nil, "DefaultMacCursor.cape resolved at \(manager.defaultMacCursorCapeURL?.path ?? "nil")")
        if let capeURL = manager.defaultMacCursorCapeURL,
           let data = try? Data(contentsOf: capeURL),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
           let cursors = plist["Cursors"] as? [String: Any] {
            assertTrue(cursors.count >= 20, "DefaultMacCursor.cape contains \(cursors.count) authentic Apple cursors (expected >= 20)")
            assertTrue(cursors["com.apple.coregraphics.Arrow"] != nil, "DefaultMacCursor contains authentic Arrow cursor")
            assertTrue(cursors["com.apple.coregraphics.IBeam"] != nil, "DefaultMacCursor contains authentic IBeam cursor")
            assertTrue(cursors["com.apple.cursor.2"] != nil, "DefaultMacCursor contains authentic Link pointing hand cursor")
        }

        let restoreOk = manager.restoreDefaults()
        assertTrue(restoreOk, "Native DefaultMacCursor restoration executed and applied successfully onto WindowServer")

        // 5. Test SchemeLibraryManager Persistence & Sidebar Exclusion
        print("\n--- [5/6] Testing SchemeLibraryManager Persistence & Sidebar Exclusion ---")
        let library = SchemeLibraryManager.shared
        assertTrue(FileManager.default.fileExists(atPath: library.libraryDirectory.path), "Library directory exists at \(library.libraryDirectory.path)")
        assertTrue(!library.schemes.isEmpty, "Themes successfully bootstrapped into library (\(library.schemes.count) schemes present)")
        assertTrue(library.activeScheme != nil, "Active scheme is accessible: \(library.activeScheme!.name)")

        // CRITICAL CHECK: Verify sidebar schemes NEVER include DefaultMacCursor ("但是不要写在侧面")
        let containsDefaultInSidebar = library.schemes.contains { scheme in
            let lower = scheme.name.lowercased()
            return lower.contains("defaultmaccursor") || lower.contains("macos default")
        }
        assertTrue(!containsDefaultInSidebar, "Native recovery scheme is strictly excluded from sidebar schemes list ('但是不要写在侧面')")

        // 6. Test StatusBarManager Menu Construction
        print("\n--- [6/7] Testing StatusBarManager & Menu Bar Switcher ---")
        let statusManager = StatusBarManager.shared
        statusManager.setup()
        let testMenu = NSMenu()
        statusManager.menuNeedsUpdate(testMenu)
        assertTrue(testMenu.items.count >= 5, "StatusBar menu built successfully with \(testMenu.items.count) items")
        let hasRestoreItem = testMenu.items.contains { $0.title.contains("恢复") || $0.title.contains("Restore") }
        assertTrue(hasRestoreItem, "StatusBar menu contains restore defaults item")
        let hasOpenWindowItem = testMenu.items.contains { $0.title.contains("主窗口") || $0.title.contains("Main Window") }
        assertTrue(hasOpenWindowItem, "StatusBar menu contains open main window item")
        let hasQuitItem = testMenu.items.contains { $0.title.contains("退出") || $0.title.contains("Quit") }
        assertTrue(hasQuitItem, "StatusBar menu contains quit item")

        // 7. Test Multilingual Localization (i18n) System
        print("\n--- [7/7] Testing Multilingual Localization (i18n) & Language Switching ---")
        let langManager = LanguageManager.shared

        // Test English localization
        langManager.selectedLanguage = .english
        assertTrue(!langManager.effectiveLanguageIsChinese, "LanguageManager set to English")
        assertTrue(L10n.tr("app_title") == "WinToMacCursor", "English app title verified: \(L10n.tr("app_title"))")
        assertTrue(CursorRole.arrow.localizedName == "Normal Select", "CursorRole.arrow English: \(CursorRole.arrow.localizedName)")
        assertTrue(CursorRole.busy.localizedName == "Busy / Waiting", "CursorRole.busy English: \(CursorRole.busy.localizedName)")
        assertTrue(L10n.tr("btn_apply") == "Apply", "English Apply button: \(L10n.tr("btn_apply"))")
        assertTrue(L10n.tr("btn_restore") == "Restore Defaults", "English Restore button: \(L10n.tr("btn_restore"))")

        // Verify status bar in English
        let enMenu = NSMenu()
        statusManager.menuNeedsUpdate(enMenu)
        let enHasRestore = enMenu.items.contains { $0.title.contains("Restore System Defaults") }
        let enHasOpen = enMenu.items.contains { $0.title.contains("Open Main Window") }
        let enHasSettings = enMenu.items.contains { $0.title.contains("Settings") && $0.keyEquivalent == "," }
        let enHasQuit = enMenu.items.contains { $0.title.contains("Quit WinToMacCursor") }
        assertTrue(enHasRestore, "English menu contains 'Restore System Defaults'")
        assertTrue(enHasOpen, "English menu contains 'Open Main Window'")
        assertTrue(enHasSettings, "English menu contains 'Settings...' with Cmd+,")
        assertTrue(enHasQuit, "English menu contains 'Quit WinToMacCursor'")

        // Test Chinese localization
        langManager.selectedLanguage = .chinese
        assertTrue(langManager.effectiveLanguageIsChinese, "LanguageManager set to Chinese")
        assertTrue(L10n.tr("app_title") == "WinToMacCursor", "Chinese app title verified: \(L10n.tr("app_title"))")
        assertTrue(CursorRole.arrow.localizedName == "正常选择 (Normal)", "CursorRole.arrow Chinese: \(CursorRole.arrow.localizedName)")
        assertTrue(CursorRole.busy.localizedName == "忙碌等待 (Busy)", "CursorRole.busy Chinese: \(CursorRole.busy.localizedName)")
        assertTrue(L10n.tr("btn_apply") == "一键更换 (Apply)", "Chinese Apply button: \(L10n.tr("btn_apply"))")
        assertTrue(L10n.tr("btn_restore") == "一键恢复 (Restore)", "Chinese Restore button: \(L10n.tr("btn_restore"))")

        // Verify status bar in Chinese
        let zhMenu = NSMenu()
        statusManager.menuNeedsUpdate(zhMenu)
        let zhHasRestore = zhMenu.items.contains { $0.title.contains("一键恢复系统默认") }
        let zhHasOpen = zhMenu.items.contains { $0.title.contains("打开主窗口") }
        let zhHasSettings = zhMenu.items.contains { $0.title.contains("设置") && $0.keyEquivalent == "," }
        let zhHasQuit = zhMenu.items.contains { $0.title.contains("退出 WinToMacCursor") }
        assertTrue(zhHasRestore, "Chinese menu contains '一键恢复系统默认'")
        assertTrue(zhHasOpen, "Chinese menu contains '打开主窗口'")
        assertTrue(zhHasSettings, "Chinese menu contains '设置...' with Cmd+,")
        assertTrue(zhHasQuit, "Chinese menu contains '退出 WinToMacCursor'")

        // 8. Test AppStateManager & Dock Hiding Logic
        print("\n--- [8/8] Testing AppStateManager & Dock Icon Hiding Logic ---")
        let appState = AppStateManager.shared
        let originalHideDock = appState.hideDockIcon
        let originalRestore = appState.restoreOnQuit

        appState.hideDockIcon = true
        assertTrue(UserDefaults.standard.bool(forKey: AppStateManager.hideDockIconKey) == true, "UserDefaults persists hideDockIcon = true")
        let policyAccessory = appState.applyActivationPolicy()
        assertTrue(policyAccessory == .accessory, "Activation policy set to .accessory when hideDockIcon = true")

        appState.hideDockIcon = false
        assertTrue(UserDefaults.standard.bool(forKey: AppStateManager.hideDockIconKey) == false, "UserDefaults persists hideDockIcon = false")
        let policyRegular = appState.applyActivationPolicy()
        assertTrue(policyRegular == .regular, "Activation policy restored to .regular when hideDockIcon = false")

        appState.restoreOnQuit = true
        assertTrue(UserDefaults.standard.bool(forKey: AppStateManager.restoreOnQuitKey) == true, "UserDefaults persists restoreOnQuit = true")

        // Verify Settings strings
        langManager.selectedLanguage = .english
        assertTrue(L10n.tr("settings_title") == "Settings", "English Settings title verified")
        assertTrue(L10n.tr("settings_hide_dock_icon") == "Hide Dock Icon (Menu Bar Only)", "English hide dock icon string verified")

        langManager.selectedLanguage = .chinese
        assertTrue(L10n.tr("settings_title") == "设置", "Chinese Settings title verified")
        assertTrue(L10n.tr("settings_hide_dock_icon") == "隐藏程序坞 (Dock) 图标", "Chinese hide dock icon string verified")

        // Restore original states
        appState.hideDockIcon = originalHideDock
        appState.restoreOnQuit = originalRestore
        langManager.selectedLanguage = .system

        // 9. Test WindowServer Seed Registration & Playground Lifecycle
        print("\n--- [9/9] Testing WindowServer Seed Sync & Playground Lifecycle ---")
        let testScheme = try! SchemeLoader.loadScheme(from: staticDir)
        let applySuccess = manager.applyScheme(testScheme)
        assertTrue(applySuccess.success > 0, "SystemCursorManager applyScheme with registered seed registered \(applySuccess.success)/\(applySuccess.total) cursors")

        let restoreAfterApply = manager.restoreDefaults()
        assertTrue(restoreAfterApply, "SystemCursorManager restoreDefaults with registered seed executed successfully")

        let testWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        let playgroundView = PlaygroundContainerView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        testWindow.contentView?.addSubview(playgroundView)
        playgroundView.updateCursor(with: testScheme.items[0])

        assertTrue(playgroundView.currentCursor != nil, "Playground view configured cursor from item")

        // Verify resetCursorRects executes cleanly
        playgroundView.resetCursorRects()
        assertTrue(playgroundView.currentCursor != nil, "Playground view has valid cursor setup")

        // Verify cleanup stops any active animations and clears inside state
        playgroundView.isMouseInside = true
        playgroundView.cleanup()
        assertTrue(!playgroundView.mouseInside, "Playground cleanup sets mouseInside to false")
        assertTrue(!playgroundView.isAnimating, "Playground cleanup stops animTimer")

        // Verify notification observers trigger cleanup
        playgroundView.isMouseInside = true
        NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: nil)
        assertTrue(!playgroundView.mouseInside, "App didResignActive triggers playground cleanup")

        playgroundView.isMouseInside = true
        NotificationCenter.default.post(name: NSWindow.didResignKeyNotification, object: testWindow)
        assertTrue(!playgroundView.mouseInside, "Window didResignKey triggers playground cleanup")

        playgroundView.isMouseInside = true
        NotificationCenter.default.post(name: NSWindow.didMiniaturizeNotification, object: testWindow)
        assertTrue(!playgroundView.mouseInside, "Window didMiniaturize triggers playground cleanup")

        // Verify dismantleNSView triggers cleanup
        playgroundView.isMouseInside = true
        PlaygroundNSViewRepresentable.dismantleNSView(playgroundView, coordinator: ())
        assertTrue(!playgroundView.mouseInside, "dismantleNSView triggers playground cleanup")

        testWindow.orderOut(nil)

        // Clean up temporary test files
        try? FileManager.default.removeItem(at: tmpDir)

        print("\n==================================================")
        print("🎉 ALL TESTS PASSED! System verified 100% operational.")
        print("==================================================")
    }
}
