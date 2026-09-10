import AppKit
import Combine
import Foundation

public final class SystemCursorManager: ObservableObject {
    public static let shared = SystemCursorManager()

    @Published public private(set) var isCustomApplied: Bool = false
    @Published public private(set) var lastAppliedSchemeName: String? = nil

    public typealias CGSConnectionID = Int32

    private var slHandle: UnsafeMutableRawPointer?
    private var asHandle: UnsafeMutableRawPointer?

    private var cgsMainConnectionIDFn: (@convention(c) () -> CGSConnectionID)?
    private var cgsRegisterCursorWithImagesFn: (@convention(c) (
        CGSConnectionID,
        UnsafePointer<CChar>,
        Bool,
        Bool,
        CGSize,
        CGPoint,
        Int,
        CGFloat,
        CFArray,
        UnsafeMutablePointer<Int32>
    ) -> Int32)?
    private var cgsSetRegisteredCursorFn: (@convention(c) (
        CGSConnectionID,
        UnsafePointer<CChar>,
        UnsafeMutablePointer<Int32>
    ) -> Int32)?
    private var cgsCopyRegisteredCursorImagesFn: (@convention(c) (
        CGSConnectionID,
        UnsafePointer<CChar>,
        UnsafeMutablePointer<CGSize>,
        UnsafeMutablePointer<CGPoint>,
        UnsafeMutablePointer<Int>,
        UnsafeMutablePointer<CGFloat>,
        UnsafeMutablePointer<Unmanaged<CFArray>?>
    ) -> Int32)?
    private var cursorConnectionID: CGSConnectionID?
    private var cgsNewConnectionFn: (@convention(c) (UnsafeMutableRawPointer?, UnsafeMutablePointer<CGSConnectionID>) -> Int32)?
    private var cgsReleaseConnectionFn: (@convention(c) (CGSConnectionID) -> Int32)?
    private var cgsRemoveRegisteredCursorFn: (@convention(c) (
        CGSConnectionID,
        UnsafePointer<CChar>
    ) -> Int32)?
    private var cgsGetCursorScaleFn: (@convention(c) (CGSConnectionID, UnsafeMutablePointer<Float>) -> Int32)?
    private var cgsSetCursorScaleFn: (@convention(c) (CGSConnectionID, Float) -> Int32)?
    private var coreCursorUnregisterAllFn: (@convention(c) (CGSConnectionID) -> Int32)?
    private var observers: [NSObjectProtocol] = []

    public var defaultMacCursorCapeURL: URL? {
        // 1. App Bundle Resources
        if let bundleURL = Bundle.main.url(forResource: "DefaultMacCursor", withExtension: "cape") {
            return bundleURL
        }
        if let resURL = Bundle.main.resourceURL?.appendingPathComponent("DefaultMacCursor.cape"),
           FileManager.default.fileExists(atPath: resURL.path) {
            return resURL
        }
        // 2. Fallback relative to source file (WinToMacCursor/DefaultMacCursor.cape)
        let sourceFile = URL(fileURLWithPath: #filePath)
        let moduleDir = sourceFile.deletingLastPathComponent().deletingLastPathComponent()
        let moduleCape = moduleDir.appendingPathComponent("DefaultMacCursor.cape")
        if FileManager.default.fileExists(atPath: moduleCape.path) {
            return moduleCape
        }
        // 3. Fallback relative to workspace root / current working directory
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let candidatePaths = [
            cwd.appendingPathComponent("WinToMacCursor/DefaultMacCursor.cape"),
            cwd.appendingPathComponent("DefaultMacCursor.cape"),
            cwd.appendingPathComponent("Resources/DefaultMacCursor.cape")
        ]
        for path in candidatePaths {
            if FileManager.default.fileExists(atPath: path.path) {
                return path
            }
        }
        return nil
    }

    private var backupDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("WinToMacCursor/SystemCursorBackup", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        } catch {
            let localDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".wintomac_data/SystemCursorBackup", isDirectory: true)
            try? FileManager.default.createDirectory(at: localDir, withIntermediateDirectories: true)
            return localDir
        }
    }

    private var manifestURL: URL {
        backupDirectory.appendingPathComponent("manifest.json")
    }

    private init() {
        loadFrameworkSymbols()
        cleanupCorruptedBackupsIfNeeded()
        setupLifecycleObservers()

        // Restore previously applied state from UserDefaults
        if let savedScheme = UserDefaults.standard.string(forKey: "WinToMacCursor_AppliedScheme") {
            self.isCustomApplied = true
            self.lastAppliedSchemeName = savedScheme
        }
    }

    private func setupLifecycleObservers() {
        let wsCenter = NSWorkspace.shared.notificationCenter
        observers.append(wsCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.handleSystemWake()
        })
        observers.append(wsCenter.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.handleSystemWake()
        })
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            self?.handleSystemWake()
        })
    }

    private func handleSystemWake() {
        guard isCustomApplied, let schemeName = lastAppliedSchemeName else { return }
        if let activeScheme = SchemeLibraryManager.shared.schemes.first(where: { $0.name == schemeName }) {
            NSLog("[SystemCursorManager] Re-applying scheme after system wake/display change: %@", schemeName)
            _ = applyScheme(activeScheme)
        }
    }

    deinit {
        if let cid = cursorConnectionID {
            _ = cgsReleaseConnectionFn?(cid)
            cursorConnectionID = nil
        }
        for obs in observers {
            NotificationCenter.default.removeObserver(obs)
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
        observers.removeAll()
    }

    private func cleanupCorruptedBackupsIfNeeded() {
        // Purge legacy backup directory if present to eliminate any previous custom cursor contamination
        if FileManager.default.fileExists(atPath: backupDirectory.path) {
            try? FileManager.default.removeItem(at: backupDirectory)
        }
    }

    private func loadFrameworkSymbols() {
        // 1. SkyLight.framework
        if let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY) {
            self.slHandle = handle

            if let ptr = dlsym(handle, "CGSMainConnectionID") {
                self.cgsMainConnectionIDFn = unsafeBitCast(ptr, to: (@convention(c) () -> CGSConnectionID).self)
            }
            if let ptr = dlsym(handle, "CGSNewConnection") {
                self.cgsNewConnectionFn = unsafeBitCast(ptr, to: (@convention(c) (UnsafeMutableRawPointer?, UnsafeMutablePointer<CGSConnectionID>) -> Int32).self)
            }
            if let ptr = dlsym(handle, "CGSReleaseConnection") {
                self.cgsReleaseConnectionFn = unsafeBitCast(ptr, to: (@convention(c) (CGSConnectionID) -> Int32).self)
            }
            if let ptr = dlsym(handle, "CGSRegisterCursorWithImages") {
                self.cgsRegisterCursorWithImagesFn = unsafeBitCast(ptr, to: (@convention(c) (
                    CGSConnectionID,
                    UnsafePointer<CChar>,
                    Bool,
                    Bool,
                    CGSize,
                    CGPoint,
                    Int,
                    CGFloat,
                    CFArray,
                    UnsafeMutablePointer<Int32>
                ) -> Int32).self)
            }
            if let ptr = dlsym(handle, "CGSSetRegisteredCursor") {
                self.cgsSetRegisteredCursorFn = unsafeBitCast(ptr, to: (@convention(c) (
                    CGSConnectionID,
                    UnsafePointer<CChar>,
                    UnsafeMutablePointer<Int32>
                ) -> Int32).self)
            }
            if let ptr = dlsym(handle, "CGSCopyRegisteredCursorImages") {
                self.cgsCopyRegisteredCursorImagesFn = unsafeBitCast(ptr, to: (@convention(c) (
                    CGSConnectionID,
                    UnsafePointer<CChar>,
                    UnsafeMutablePointer<CGSize>,
                    UnsafeMutablePointer<CGPoint>,
                    UnsafeMutablePointer<Int>,
                    UnsafeMutablePointer<CGFloat>,
                    UnsafeMutablePointer<Unmanaged<CFArray>?>
                ) -> Int32).self)
            }
            if let ptr = dlsym(handle, "CGSRemoveRegisteredCursor") {
                self.cgsRemoveRegisteredCursorFn = unsafeBitCast(ptr, to: (@convention(c) (
                    CGSConnectionID,
                    UnsafePointer<CChar>
                ) -> Int32).self)
            }
            if let ptr = dlsym(handle, "CGSGetCursorScale") {
                self.cgsGetCursorScaleFn = unsafeBitCast(ptr, to: (@convention(c) (CGSConnectionID, UnsafeMutablePointer<Float>) -> Int32).self)
            }
            if let ptr = dlsym(handle, "CGSSetCursorScale") {
                self.cgsSetCursorScaleFn = unsafeBitCast(ptr, to: (@convention(c) (CGSConnectionID, Float) -> Int32).self)
            }
        }

        // 2. ApplicationServices.framework for system-wide CoreCursorUnregisterAll
        if let handle = dlopen("/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices", RTLD_LAZY) {
            self.asHandle = handle
            if let ptr = dlsym(handle, "CoreCursorUnregisterAll") {
                self.coreCursorUnregisterAllFn = unsafeBitCast(ptr, to: (@convention(c) (CGSConnectionID) -> Int32).self)
            }
        }
    }

    public var connectionID: CGSConnectionID? {
        cgsMainConnectionIDFn?()
    }

    public var isAvailable: Bool {
        cgsMainConnectionIDFn != nil &&
        cgsRegisterCursorWithImagesFn != nil &&
        cgsSetRegisteredCursorFn != nil
    }

    // MARK: - Cursor Operations

    public func triggerCursorRedraw() {
        guard let cid = connectionID else { return }
        var currentScale: Float = 1.0
        if let getScale = cgsGetCursorScaleFn, let setScale = cgsSetCursorScaleFn {
            if getScale(cid, &currentScale) == 0 {
                _ = setScale(cid, currentScale + 0.05)
                _ = setScale(cid, currentScale)
            }
        }
        NSCursor.unhide()

        // Synthesize a pair of micro mouseMoved CGEvents to force WindowServer
        // and foreground apps (e.g. Word, Safari, Notes) to update their cursor rects immediately
        if let event = CGEvent(source: nil) {
            let loc = event.location
            let move1 = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: CGPoint(x: loc.x + 1, y: loc.y), mouseButton: .left)
            let move2 = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: loc, mouseButton: .left)
            move1?.post(tap: .cghidEventTap)
            move2?.post(tap: .cghidEventTap)
        }
    }

    @discardableResult
    public func applyScheme(_ scheme: CursorScheme) -> (success: Int, total: Int) {
        guard isAvailable, let registerFn = cgsRegisterCursorWithImagesFn else {
            NSLog("[SystemCursorManager] Required SkyLight APIs not available")
            return (0, 0)
        }

        // Release previous dedicated cursor connection if one exists
        if let oldCid = cursorConnectionID {
            _ = cgsReleaseConnectionFn?(oldCid)
            cursorConnectionID = nil
        }

        // Create a new dedicated connection to register custom cursors
        var targetCid: CGSConnectionID = 0
        if let newConn = cgsNewConnectionFn, newConn(nil, &targetCid) == 0 {
            self.cursorConnectionID = targetCid
        } else if let mainCid = connectionID {
            targetCid = mainCid
        } else {
            NSLog("[SystemCursorManager] Failed to obtain CGS connection")
            return (0, 0)
        }

        var successCount = 0
        var totalCount = 0

        for item in scheme.items {
            guard !item.frames.isEmpty else { continue }

            let frameCount = item.isAnimated ? item.frames.count : 1
            let frameDuration = CGFloat(item.isAnimated ? item.frameRate : 0.0)
            let hotspot = item.hotspot
            let size = item.size

            var cgImages: [CGImage] = []
            if item.isAnimated && item.frames.count > 1 {
                // SkyLight CGSRegisterCursorWithImages treats each image in CFArray as a scale representation (1x, 2x)
                // For animated cursors, each scale representation MUST be a vertical sprite sheet of height (size.height * frameCount)
                let frameImages = item.frames.map(\.image)
                if let sheet1x = CapeGenerator.createVerticalSpriteSheetImage(frames: frameImages, singleSize: size, scale: 1.0) {
                    cgImages.append(sheet1x)
                }
                if let sheet2x = CapeGenerator.createVerticalSpriteSheetImage(frames: frameImages, singleSize: size, scale: 2.0) {
                    cgImages.append(sheet2x)
                }
            } else if let firstFrame = item.frames.first {
                // Static cursor (1 frame) representations
                if let rep1x = CapeGenerator.createVerticalSpriteSheetImage(frames: [firstFrame.image], singleSize: size, scale: 1.0) {
                    cgImages.append(rep1x)
                }
                if let rep2x = CapeGenerator.createVerticalSpriteSheetImage(frames: [firstFrame.image], singleSize: size, scale: 2.0) {
                    cgImages.append(rep2x)
                }
            }

            guard !cgImages.isEmpty else { continue }

            let identifiers = item.role.macIdentifiers
            for ident in identifiers {
                totalCount += 1

                var seed: Int32 = 0
                let regErr = registerFn(
                    targetCid,
                    ident,
                    true,
                    true,
                    size,
                    hotspot,
                    frameCount,
                    frameDuration,
                    cgImages as CFArray,
                    &seed
                )

                if regErr == 0 {
                    successCount += 1
                } else {
                    NSLog("[SystemCursorManager] Failed to register %s, err: %d", ident, regErr)
                }
            }
        }

        UserDefaults.standard.set(scheme.name, forKey: "WinToMacCursor_AppliedScheme")

        DispatchQueue.main.async {
            self.isCustomApplied = (successCount > 0)
            self.lastAppliedSchemeName = scheme.name
            self.triggerCursorRedraw()
        }

        return (successCount, totalCount)
    }

    @discardableResult
    public func restoreDefaults() -> Bool {
        var didRestore = false

        // 1. Release dedicated cursor connection if active
        if let cid = cursorConnectionID {
            let _ = cgsReleaseConnectionFn?(cid)
            cursorConnectionID = nil
        }

        // 2. Safety fallback: unregister CoreCursor
        if let mainCid = connectionID, let unregisterAll = coreCursorUnregisterAllFn {
            _ = unregisterAll(mainCid)
        }

        // 3. Forcibly overwrite custom cursors using authentic Apple macOS assets from DefaultMacCursor.cape
        // This instantly and deterministically restores Arrow, IBeam, Resize, and tools across all applications
        // without seed conflicts or disappearing cursors.
        if let capeURL = defaultMacCursorCapeURL,
           let data = try? Data(contentsOf: capeURL),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
           let cursors = plist["Cursors"] as? [String: [String: Any]],
           let cid = connectionID,
           let registerFn = cgsRegisterCursorWithImagesFn {
            
            var restoredCount = 0
            for (ident, dict) in cursors {
                let frameCount = dict["FrameCount"] as? Int ?? 1
                let frameDuration = dict["FrameDuration"] as? Double ?? 0.0
                let hx = dict["HotSpotX"] as? Double ?? 0.0
                let hy = dict["HotSpotY"] as? Double ?? 0.0
                let w = dict["PointsWide"] as? Double ?? 32.0
                let h = dict["PointsHigh"] as? Double ?? 32.0
                let reps = dict["Representations"] as? [Data] ?? []

                var cgImages: [CGImage] = []
                for repData in reps {
                    if let src = CGImageSourceCreateWithData(repData as CFData, nil),
                       let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) {
                        cgImages.append(cg)
                    }
                }
                guard !cgImages.isEmpty else { continue }

                var seed: Int32 = 0
                let regErr = registerFn(
                    cid,
                    ident,
                    true,
                    true,
                    CGSize(width: w, height: h),
                    CGPoint(x: hx, y: hy),
                    frameCount,
                    CGFloat(frameDuration),
                    cgImages as CFArray,
                    &seed
                )
                if regErr == 0 {
                    restoredCount += 1
                }
            }
            NSLog("[SystemCursorManager] Restored %d default cursors from DefaultMacCursor.cape", restoredCount)
            if restoredCount > 0 {
                didRestore = true
            }
        }

        // 4. Hot-refresh WindowServer cursor cache using CGSSetCursorScale and synthetic mouse movement
        triggerCursorRedraw()
        didRestore = true

        // 5. Clear persisted applied state and legacy corrupted cache
        cleanupCorruptedBackupsIfNeeded()
        UserDefaults.standard.removeObject(forKey: "WinToMacCursor_AppliedScheme")

        DispatchQueue.main.async {
            self.isCustomApplied = false
            self.lastAppliedSchemeName = nil
        }

        return didRestore
    }
}
