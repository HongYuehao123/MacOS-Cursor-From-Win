import AppKit
import Foundation

@main
struct Exporter {
    static func main() {
        let cwd = FileManager.default.currentDirectoryPath
        let testDir = URL(fileURLWithPath: cwd).appendingPathComponent("Test")
        let outDir = URL(fileURLWithPath: cwd).appendingPathComponent("dist/Mousecape Themes")
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        let staticDir = testDir.appendingPathComponent("Minori Cursor static")
        let aniDir = testDir.appendingPathComponent("Minori Cursor animation")

        do {
            let sScheme = try SchemeLoader.loadScheme(from: staticDir)
            let sDest = outDir.appendingPathComponent("Hanasato_Minori_Static.cape")
            try CapeGenerator.exportCape(from: sScheme, to: sDest)
            print("✅ 成功导出: \(sDest.path)")

            let aScheme = try SchemeLoader.loadScheme(from: aniDir)
            let aDest = outDir.appendingPathComponent("Hanasato_Minori_Animated.cape")
            try CapeGenerator.exportCape(from: aScheme, to: aDest)
            print("✅ 成功导出: \(aDest.path)")
        } catch {
            print("❌ 导出失败: \(error)")
        }
    }
}
