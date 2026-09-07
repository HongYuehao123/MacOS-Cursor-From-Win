import AppKit
import Foundation

public struct WindowsCursorParser {

    public enum ParseError: LocalizedError {
        case fileNotFound
        case invalidHeader(String)
        case unsupportedFormat(String)
        case noValidFrames
        
        public var errorDescription: String? {
            switch self {
            case .fileNotFound: return "光标文件不存在"
            case .invalidHeader(let msg): return "文件头无效: \(msg)"
            case .unsupportedFormat(let msg): return "不支持的格式: \(msg)"
            case .noValidFrames: return "未找到有效的图像帧"
            }
        }
    }

    public static func parseFile(at url: URL, role: CursorRole? = nil) throws -> CursorItem {
        let data = try Data(contentsOf: url)
        let filename = url.lastPathComponent
        let resolvedRole = role ?? CursorRole.match(fromFileName: filename)
        let name = url.deletingPathExtension().lastPathComponent

        if isANI(data: data) {
            return try parseANI(data: data, name: name, filename: filename, role: resolvedRole)
        } else if isCUR(data: data) {
            return try parseCUR(data: data, name: name, filename: filename, role: resolvedRole)
        } else {
            // Check if it can still be opened as an image
            if let image = NSImage(data: data) {
                let frame = CursorFrame(
                    image: image,
                    hotspot: CGPoint(x: image.size.width / 2, y: image.size.height / 2),
                    duration: 0.0,
                    size: image.size
                )
                return CursorItem(
                    role: resolvedRole,
                    name: name,
                    sourceFileName: filename,
                    isAnimated: false,
                    frames: [frame],
                    frameRate: 0.0,
                    hotspot: frame.hotspot,
                    size: frame.size
                )
            }
            throw ParseError.unsupportedFormat("文件既不是 ANI 也不是 CUR 格式")
        }
    }

    public static func isCUR(data: Data) -> Bool {
        guard data.count >= 6 else { return false }
        let reserved = data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt16.self) }
        let idType = data.withUnsafeBytes { $0.load(fromByteOffset: 2, as: UInt16.self) }
        return reserved == 0 && (idType == 2 || idType == 1) // 2=CUR, 1=ICO
    }

    public static func isANI(data: Data) -> Bool {
        guard data.count >= 12 else { return false }
        let riff = String(decoding: data[0..<4], as: UTF8.self)
        let acon = String(decoding: data[8..<12], as: UTF8.self)
        return riff == "RIFF" && acon == "ACON"
    }

    public static func parseCUR(data: Data, name: String, filename: String, role: CursorRole) throws -> CursorItem {
        guard data.count >= 6 else { throw ParseError.invalidHeader("数据长度小于 6 字节") }
        let reserved = data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt16.self) }
        let idType = data.withUnsafeBytes { $0.load(fromByteOffset: 2, as: UInt16.self) }
        let idCount = Int(data.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt16.self) })

        guard reserved == 0, idType == 2 || idType == 1, idCount > 0 else {
            throw ParseError.invalidHeader("CUR/ICO 标头校验未通过")
        }

        guard let image = NSImage(data: data) else {
            throw ParseError.noValidFrames
        }

        // Extract hotspot from first entry
        var hotspot = CGPoint(x: 0, y: 0)
        if data.count >= 6 + 16 {
            let hx = Double(data.withUnsafeBytes { $0.load(fromByteOffset: 10, as: UInt16.self) })
            let hy = Double(data.withUnsafeBytes { $0.load(fromByteOffset: 12, as: UInt16.self) })
            hotspot = CGPoint(x: hx, y: hy)
        }

        let size = image.size
        let frame = CursorFrame(image: image, hotspot: hotspot, duration: 0.0, size: size)

        return CursorItem(
            role: role,
            name: name,
            sourceFileName: filename,
            isAnimated: false,
            frames: [frame],
            frameRate: 0.0,
            hotspot: hotspot,
            size: size
        )
    }

    public static func parseANI(data: Data, name: String, filename: String, role: CursorRole) throws -> CursorItem {
        guard isANI(data: data) else { throw ParseError.invalidHeader("非合法 RIFF ACON 文件") }

        var pos = 12
        var rawFrames: [(image: NSImage, hotspot: CGPoint, size: CGSize)] = []
        var jifRate: Double = 5.0 // default 5/60s ~ 0.083s
        var sequence: [Int]? = nil

        while pos + 8 <= data.count {
            let chunkId = String(decoding: data[pos..<pos+4], as: UTF8.self)
            let chunkSize = Int(data.subdata(in: pos+4..<pos+8).withUnsafeBytes { $0.load(as: UInt32.self) })
            pos += 8
            guard pos + chunkSize <= data.count else { break }
            let chunkData = data.subdata(in: pos..<pos+chunkSize)

            if chunkId == "anih" && chunkData.count >= 36 {
                let rate = Double(chunkData.withUnsafeBytes { $0.load(fromByteOffset: 28, as: UInt32.self) })
                if rate > 0 { jifRate = rate }
            } else if chunkId == "seq " {
                let count = chunkSize / 4
                var seq: [Int] = []
                for i in 0..<count {
                    let idx = Int(chunkData.withUnsafeBytes { $0.load(fromByteOffset: i * 4, as: UInt32.self) })
                    seq.append(idx)
                }
                sequence = seq
            } else if chunkId == "LIST" && chunkData.count >= 4 {
                let listType = String(decoding: chunkData[0..<4], as: UTF8.self)
                if listType == "fram" {
                    var fpos = 4
                    while fpos + 8 <= chunkData.count {
                        let cid = String(decoding: chunkData[fpos..<fpos+4], as: UTF8.self)
                        let csz = Int(chunkData.subdata(in: fpos+4..<fpos+8).withUnsafeBytes { $0.load(as: UInt32.self) })
                        fpos += 8
                        guard fpos + csz <= chunkData.count else { break }
                        let iconBytes = chunkData.subdata(in: fpos..<fpos+csz)
                        
                        if cid == "icon" {
                            if let img = NSImage(data: iconBytes) {
                                var hx: Double = 0
                                var hy: Double = 0
                                if iconBytes.count >= 14 {
                                    hx = Double(iconBytes.withUnsafeBytes { $0.load(fromByteOffset: 10, as: UInt16.self) })
                                    hy = Double(iconBytes.withUnsafeBytes { $0.load(fromByteOffset: 12, as: UInt16.self) })
                                }
                                rawFrames.append((image: img, hotspot: CGPoint(x: hx, y: hy), size: img.size))
                            }
                        }
                        
                        fpos += csz
                        if csz % 2 != 0 { fpos += 1 }
                    }
                }
            }

            pos += chunkSize
            if chunkSize % 2 != 0 { pos += 1 }
        }

        guard !rawFrames.isEmpty else {
            throw ParseError.noValidFrames
        }

        let orderedRaw: [(image: NSImage, hotspot: CGPoint, size: CGSize)]
        if let seq = sequence, !seq.isEmpty {
            orderedRaw = seq.compactMap { idx in
                if idx < rawFrames.count { return rawFrames[idx] }
                return nil
            }
        } else {
            orderedRaw = rawFrames
        }

        let finalRaw = orderedRaw.isEmpty ? rawFrames : orderedRaw
        let frameDuration = max(0.016, jifRate / 60.0)

        let frames = finalRaw.map { raw in
            CursorFrame(image: raw.image, hotspot: raw.hotspot, duration: frameDuration, size: raw.size)
        }

        let primaryHotspot = frames.first?.hotspot ?? CGPoint.zero
        let primarySize = frames.first?.size ?? CGSize(width: 32, height: 32)

        return CursorItem(
            role: role,
            name: name,
            sourceFileName: filename,
            isAnimated: true,
            frames: frames,
            frameRate: frameDuration,
            hotspot: primaryHotspot,
            size: primarySize
        )
    }
}
