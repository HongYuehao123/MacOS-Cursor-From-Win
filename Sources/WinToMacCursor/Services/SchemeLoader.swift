import Foundation

public struct SchemeLoader {

    public static func loadScheme(from directoryURL: URL) throws -> CursorScheme {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)

        var schemeName = directoryURL.lastPathComponent
        let author = "Windows Cursor Converter"
        var items: [CursorItem] = []
        var isAnimated = false

        // Check for install.inf
        let infURL = directoryURL.appendingPathComponent("install.inf")
        if fileManager.fileExists(atPath: infURL.path) {
            let info = try INFParser.parse(url: infURL)
            if !info.schemeName.isEmpty {
                schemeName = info.schemeName
            }

            for (role, filename) in info.roleFiles {
                let fileURL = directoryURL.appendingPathComponent(filename)
                if fileManager.fileExists(atPath: fileURL.path) {
                    if let item = try? WindowsCursorParser.parseFile(at: fileURL, role: role) {
                        items.append(item)
                        if item.isAnimated { isAnimated = true }
                    }
                }
            }
        }

        // Also discover any other .cur / .ani in the folder that were not in inf
        let existingFilenames = Set(items.map { $0.sourceFileName.lowercased() })
        for url in contents {
            let ext = url.pathExtension.lowercased()
            guard ext == "cur" || ext == "ani" else { continue }
            if existingFilenames.contains(url.lastPathComponent.lowercased()) { continue }

            if let item = try? WindowsCursorParser.parseFile(at: url) {
                items.append(item)
                if item.isAnimated { isAnimated = true }
            }
        }

        // Sort items by canonical role order
        let roleOrder: [CursorRole] = [
            .arrow, .link, .working, .busy, .text, .precision,
            .vertical, .horizontal, .diagonal1, .diagonal2,
            .move, .unavailable, .alternate, .help, .handwriting,
            .person, .pin, .custom
        ]

        items.sort { a, b in
            let idxA = roleOrder.firstIndex(of: a.role) ?? 999
            let idxB = roleOrder.firstIndex(of: b.role) ?? 999
            return idxA < idxB
        }

        return CursorScheme(
            name: schemeName,
            author: author,
            sourceDirectory: directoryURL,
            isAnimatedScheme: isAnimated,
            items: items
        )
    }
}
