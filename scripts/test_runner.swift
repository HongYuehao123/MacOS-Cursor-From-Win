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
        print("\n--- [5/5] Testing SchemeLibraryManager Persistence & Sidebar Exclusion ---")
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

        // Clean up temporary test files
        try? FileManager.default.removeItem(at: tmpDir)

        print("\n==================================================")
        print("🎉 ALL TESTS PASSED! System verified 100% operational.")
        print("==================================================")
    }
}
