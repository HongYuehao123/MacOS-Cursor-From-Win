import AppKit
import Combine
import Foundation

public final class SchemeLibraryManager: ObservableObject {
    public static let shared = SchemeLibraryManager()

    @Published public private(set) var schemes: [CursorScheme] = []
    @Published public var selectedSchemeIndex: Int = 0 {
        didSet {
            UserDefaults.standard.set(selectedSchemeIndex, forKey: "WinToMacCursor_SelectedSchemeIndex")
            if selectedSchemeIndex >= 0 && selectedSchemeIndex < schemes.count {
                selectedItemId = schemes[selectedSchemeIndex].items.first?.id
            }
        }
    }
    @Published public var selectedItemId: UUID? = nil

    public var activeScheme: CursorScheme? {
        guard selectedSchemeIndex >= 0 && selectedSchemeIndex < schemes.count else { return schemes.first }
        return schemes[selectedSchemeIndex]
    }

    public var libraryDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("WinToMacCursor/Themes", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        } catch {
            let localDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".wintomac_data/Themes", isDirectory: true)
            try? FileManager.default.createDirectory(at: localDir, withIntermediateDirectories: true)
            return localDir
        }
    }

    private init() {
        bootstrapDefaultThemesIfNeeded()
        reloadSchemes()

        let savedIndex = UserDefaults.standard.integer(forKey: "WinToMacCursor_SelectedSchemeIndex")
        if savedIndex >= 0 && savedIndex < schemes.count {
            self.selectedSchemeIndex = savedIndex
        } else if !schemes.isEmpty {
            self.selectedSchemeIndex = 0
        }
        self.selectedItemId = activeScheme?.items.first?.id
    }

    public func bootstrapDefaultThemesIfNeeded() {
        let existing = (try? FileManager.default.contentsOfDirectory(at: libraryDirectory, includingPropertiesForKeys: nil)) ?? []
        let hasSubdirs = existing.contains { url in
            var isDir: ObjCBool = false
            return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
        }

        if !hasSubdirs {
            var defaultThemesSource: URL? = nil
            if let bundleResource = Bundle.main.resourceURL?.appendingPathComponent("DefaultThemes"),
               FileManager.default.fileExists(atPath: bundleResource.path) {
                defaultThemesSource = bundleResource
            } else {
                // Fallback to project Test directory if running during development
                let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                let testDir = cwd.appendingPathComponent("Test")
                if FileManager.default.fileExists(atPath: testDir.path) {
                    defaultThemesSource = testDir
                }
            }

            if let src = defaultThemesSource {
                copyThemesFromSource(src)
            }
        }
    }

    private func copyThemesFromSource(_ sourceURL: URL) {
        guard let items = try? FileManager.default.contentsOfDirectory(at: sourceURL, includingPropertiesForKeys: nil) else { return }
        for item in items {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
                let dest = libraryDirectory.appendingPathComponent(item.lastPathComponent)
                if !FileManager.default.fileExists(atPath: dest.path) {
                    try? FileManager.default.copyItem(at: item, to: dest)
                }
            }
        }
    }

    public func reloadSchemes() {
        guard let items = try? FileManager.default.contentsOfDirectory(at: libraryDirectory, includingPropertiesForKeys: nil) else {
            return
        }

        var loaded: [CursorScheme] = []
        for itemURL in items.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let fname = itemURL.lastPathComponent.lowercased()
            // Strictly exclude any internal system recovery files or hidden files from sidebar
            if fname.hasPrefix(".") || fname.contains("defaultmaccursor") || fname.contains("macos default") {
                continue
            }

            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: itemURL.path, isDirectory: &isDir) && isDir.boolValue {
                if let scheme = try? SchemeLoader.loadScheme(from: itemURL) {
                    let lowerName = scheme.name.lowercased()
                    if !lowerName.contains("defaultmaccursor") && !lowerName.contains("macos default") {
                        loaded.append(scheme)
                    }
                }
            }
        }

        // Animated schemes prioritized at the top
        loaded.sort { (s1, s2) -> Bool in
            if s1.isAnimatedScheme && !s2.isAnimatedScheme { return true }
            if !s1.isAnimatedScheme && s2.isAnimatedScheme { return false }
            return s1.name < s2.name
        }

        self.schemes = loaded
        if selectedSchemeIndex >= schemes.count {
            selectedSchemeIndex = max(0, schemes.count - 1)
        }
        self.selectedItemId = activeScheme?.items.first?.id
    }

    @discardableResult
    public func importScheme(from url: URL) throws -> CursorScheme {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        guard exists else {
            throw NSError(domain: "WinToMacCursor", code: 404, userInfo: [NSLocalizedDescriptionKey: L10n.tr("path_not_exist")])
        }

        if isDir.boolValue {
            // Folder import
            let schemeName = url.lastPathComponent
            let destURL = getUniqueDestinationURL(for: schemeName)
            try FileManager.default.copyItem(at: url, to: destURL)
            let scheme = try SchemeLoader.loadScheme(from: destURL)

            reloadSchemes()
            if let idx = schemes.firstIndex(where: { $0.name == scheme.name }) {
                self.selectedSchemeIndex = idx
            }
            return scheme
        } else {
            // Single file import (.cur or .ani)
            let baseName = url.deletingPathExtension().lastPathComponent
            let destFolder = getUniqueDestinationURL(for: baseName)
            try FileManager.default.createDirectory(at: destFolder, withIntermediateDirectories: true)
            let destFile = destFolder.appendingPathComponent(url.lastPathComponent)
            try FileManager.default.copyItem(at: url, to: destFile)

            let item = try WindowsCursorParser.parseFile(at: destFile)
            let scheme = CursorScheme(name: item.name, author: "User Import", isAnimatedScheme: item.isAnimated, items: [item])

            reloadSchemes()
            if let idx = schemes.firstIndex(where: { $0.name == scheme.name }) {
                self.selectedSchemeIndex = idx
            }
            return scheme
        }
    }

    private func getUniqueDestinationURL(for name: String) -> URL {
        var candidate = libraryDirectory.appendingPathComponent(name)
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = libraryDirectory.appendingPathComponent("\(name) \(counter)")
            counter += 1
        }
        return candidate
    }

    public func deleteScheme(at index: Int) {
        guard index >= 0 && index < schemes.count else { return }
        let scheme = schemes[index]

        if let items = try? FileManager.default.contentsOfDirectory(at: libraryDirectory, includingPropertiesForKeys: nil) {
            for itemURL in items {
                if let loaded = try? SchemeLoader.loadScheme(from: itemURL), loaded.name == scheme.name {
                    try? FileManager.default.removeItem(at: itemURL)
                    break
                }
            }
        }

        reloadSchemes()
    }
}
