import AppKit
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
    private var cgsRemoveRegisteredCursorFn: (@convention(c) (
        CGSConnectionID,
        UnsafePointer<CChar>
    ) -> Int32)?
    private var coreCursorUnregisterAllFn: (@convention(c) () -> Int32)?

    public var defaultMacCursorCapeURL: URL? {
        // 1. App Bundle Resources
        if let bundleURL = Bundle.main.url(forResource: "DefaultMacCursor", withExtension: "cape") {
            return bundleURL
        }
        if let resURL = Bundle.main.resourceURL?.appendingPathComponent("DefaultMacCursor.cape"),
           FileManager.default.fileExists(atPath: resURL.path) {
            return resURL
        }
        // 2. Fallback to project Resources during development or testing
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let devURL = cwd.appendingPathComponent("Resources/DefaultMacCursor.cape")
        if FileManager.default.fileExists(atPath: devURL.path) {
            return devURL
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

        // Restore previously applied state from UserDefaults
        if let savedScheme = UserDefaults.standard.string(forKey: "WinToMacCursor_AppliedScheme") {
            self.isCustomApplied = true
            self.lastAppliedSchemeName = savedScheme
        }
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
        }

        // 2. ApplicationServices.framework for system-wide CoreCursorUnregisterAll
        if let handle = dlopen("/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices", RTLD_LAZY) {
            self.asHandle = handle
            if let ptr = dlsym(handle, "CoreCursorUnregisterAll") {
                self.coreCursorUnregisterAllFn = unsafeBitCast(ptr, to: (@convention(c) () -> Int32).self)
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

    @discardableResult
    public func applyScheme(_ scheme: CursorScheme) -> (success: Int, total: Int) {
        guard isAvailable, let cid = connectionID, let registerFn = cgsRegisterCursorWithImagesFn, let activateFn = cgsSetRegisteredCursorFn else {
            NSLog("[SystemCursorManager] Required SkyLight APIs not available")
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
                    cid,
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
                    var actSeed: Int32 = 0
                    let _ = activateFn(cid, ident, &actSeed)
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
            NSCursor.unhide()
            NSCursor.arrow.set()
        }

        return (successCount, totalCount)
    }

    @discardableResult
    public func restoreDefaults() -> Bool {
        var didRestore = false

        // 1. Call CoreCursorUnregisterAll to unregister all custom overrides from WindowServer
        if let unregisterAll = coreCursorUnregisterAllFn {
            let ret = unregisterAll()
            if ret == 0 {
                didRestore = true
                NSLog("[SystemCursorManager] CoreCursorUnregisterAll succeeded (ret: 0)")
            } else {
                NSLog("[SystemCursorManager] CoreCursorUnregisterAll returned %d", ret)
            }
        }

        // 2. Also remove registered custom cursors per identifier using CGSRemoveRegisteredCursor
        if let cid = connectionID, let removeFn = cgsRemoveRegisteredCursorFn {
            for role in CursorRole.allCases {
                for ident in role.macIdentifiers {
                    let _ = removeFn(cid, ident)
                }
            }
        }

        // 3. Register authentic Apple macOS default cursors from bundled DefaultMacCursor.cape
        if let capeURL = defaultMacCursorCapeURL,
           let data = try? Data(contentsOf: capeURL),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
           let cursors = plist["Cursors"] as? [String: [String: Any]],
           let cid = connectionID,
           let registerFn = cgsRegisterCursorWithImagesFn,
           let activateFn = cgsSetRegisteredCursorFn {
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
                    var actSeed: Int32 = 0
                    let _ = activateFn(cid, ident, &actSeed)
                    didRestore = true
                }
            }
            NSLog("[SystemCursorManager] Restored system defaults using DefaultMacCursor.cape")
        }

        // 4. Force system cursor redraw & clear persisted applied state and legacy corrupted cache
        cleanupCorruptedBackupsIfNeeded()
        UserDefaults.standard.removeObject(forKey: "WinToMacCursor_AppliedScheme")

        DispatchQueue.main.async {
            self.isCustomApplied = false
            self.lastAppliedSchemeName = nil
            NSCursor.unhide()
            NSCursor.arrow.set()
        }

        return didRestore || coreCursorUnregisterAllFn != nil
    }
}
