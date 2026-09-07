import AppKit
import Foundation

public struct CapeGenerator {

    public enum CapeError: LocalizedError {
        case serializationFailed
        case emptyScheme
        
        public var errorDescription: String? {
            switch self {
            case .serializationFailed: return L10n.tr("cape_err_serialization")
            case .emptyScheme: return L10n.tr("cape_err_empty")
            }
        }
    }

    public static func generateCapeDictionary(from scheme: CursorScheme) throws -> [String: Any] {
        guard !scheme.items.isEmpty else {
            throw CapeError.emptyScheme
        }

        var cursorsDict: [String: Any] = [:]

        for item in scheme.items {
            guard !item.frames.isEmpty else { continue }
            
            let frameCount = item.frames.count
            let frameDuration = item.isAnimated ? item.frameRate : 0.0
            let hotspot = item.hotspot
            let size = item.size

            var representations: [Data] = []
            if frameCount > 1 {
                // Synthesize vertical sprite sheet (1x standard and 2x Retina)
                let frameImages = item.frames.map(\.image)
                if let sheet1x = createVerticalSpriteSheet(frames: frameImages, singleSize: size, scale: 1.0) {
                    representations.append(sheet1x)
                }
                if let sheet2x = createVerticalSpriteSheet(frames: frameImages, singleSize: size, scale: 2.0) {
                    representations.append(sheet2x)
                }
                if representations.isEmpty, let fallback = item.previewImage.tiffRepresentation.flatMap({ NSBitmapImageRep(data: $0)?.representation(using: .png, properties: [:]) }) {
                    representations.append(fallback)
                }
            } else {
                guard let firstImg = item.frames.first?.image,
                      let tiff = firstImg.tiffRepresentation,
                      let rep = NSBitmapImageRep(data: tiff),
                      let png = rep.representation(using: .png, properties: [:]) else {
                    continue
                }
                representations.append(png)
                if let rep2x = createVerticalSpriteSheet(frames: [firstImg], singleSize: size, scale: 2.0) {
                    representations.append(rep2x)
                }
            }

            guard !representations.isEmpty else { continue }

            let cursorEntry: [String: Any] = [
                "FrameCount": frameCount,
                "FrameDuration": frameDuration,
                "HotSpotX": Double(hotspot.x),
                "HotSpotY": Double(hotspot.y),
                "PointsWide": Double(size.width),
                "PointsHigh": Double(size.height),
                "Representations": representations
            ]

            // Register all mapped identifiers for this role
            let identifiers = item.role.macIdentifiers
            if identifiers.isEmpty {
                // Fallback custom identifier
                let customId = "com.apple.cursor.\(item.name.lowercased())"
                cursorsDict[customId] = cursorEntry
            } else {
                for ident in identifiers {
                    cursorsDict[ident] = cursorEntry
                }
            }
        }

        let bundleId = "com.wintomaccursor.\(sanitizeIdentifier(scheme.name))"
        let capeDict: [String: Any] = [
            "Author": scheme.author,
            "CapeName": scheme.name,
            "CapeVersion": 2.0,
            "Cloud": false,
            "HiDPI": true,
            "Identifier": bundleId,
            "Cursors": cursorsDict
        ]

        return capeDict
    }

    public static func generateCapeData(from scheme: CursorScheme) throws -> Data {
        let dict = try generateCapeDictionary(from: scheme)
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
            return data
        } catch {
            throw CapeError.serializationFailed
        }
    }

    public static func exportCape(from scheme: CursorScheme, to destinationURL: URL) throws {
        let data = try generateCapeData(from: scheme)
        try data.write(to: destinationURL, options: .atomic)
    }

    public static func createVerticalSpriteSheetRep(frames: [NSImage], singleSize: CGSize, scale: CGFloat = 1.0) -> NSBitmapImageRep? {
        guard !frames.isEmpty else { return nil }

        let frameW = max(1, Int(round(singleSize.width * scale)))
        let frameH = max(1, Int(round(singleSize.height * scale)))
        let totalH = frameH * frames.count

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: frameW,
            pixelsHigh: totalH,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: frameW * 4,
            bitsPerPixel: 32
        ) else { return nil }

        rep.size = NSSize(width: frameW, height: totalH)

        guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx

        // Frame 0 at top: in Cocoa NSGraphicsContext (bottom-left origin), y = totalH - (i+1)*frameH
        for (i, frame) in frames.enumerated() {
            let destY = CGFloat(totalH - (i + 1) * frameH)
            frame.draw(
                in: NSRect(x: 0, y: destY, width: CGFloat(frameW), height: CGFloat(frameH)),
                from: NSRect(origin: .zero, size: frame.size),
                operation: .sourceOver,
                fraction: 1.0
            )
        }

        ctx.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()

        return rep
    }

    public static func createVerticalSpriteSheetImage(frames: [NSImage], singleSize: CGSize, scale: CGFloat = 1.0) -> CGImage? {
        return createVerticalSpriteSheetRep(frames: frames, singleSize: singleSize, scale: scale)?.cgImage
    }

    public static func createVerticalSpriteSheet(frames: [NSImage], singleSize: CGSize, scale: CGFloat = 1.0) -> Data? {
        return createVerticalSpriteSheetRep(frames: frames, singleSize: singleSize, scale: scale)?.representation(using: .png, properties: [:])
    }

    private static func sanitizeIdentifier(_ string: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_"))
        let filtered = string.unicodeScalars.filter { allowed.contains($0) }
        let result = String(String.UnicodeScalarView(filtered)).lowercased()
        return result.isEmpty ? "scheme" : result
    }
}
