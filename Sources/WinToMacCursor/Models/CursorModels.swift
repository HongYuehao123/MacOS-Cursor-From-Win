import AppKit
import Foundation

public enum CursorRole: String, CaseIterable, Identifiable, Sendable {
    case arrow = "Arrow"
    case help = "Help"
    case working = "Working"
    case busy = "Busy"
    case precision = "Precision"
    case text = "Text"
    case handwriting = "Handwriting"
    case unavailable = "Unavailable"
    case vertical = "Vertical"
    case horizontal = "Horizontal"
    case diagonal1 = "Diagonal1"
    case diagonal2 = "Diagonal2"
    case move = "Move"
    case alternate = "Alternate"
    case link = "Link"
    case person = "Person"
    case pin = "Pin"
    case custom = "Custom"

    public var id: String { rawValue }

    public var localizedName: String {
        switch self {
        case .arrow: return "正常选择 (Normal)"
        case .help: return "帮助选择 (Help)"
        case .working: return "后台工作 (Working)"
        case .busy: return "忙碌等待 (Busy)"
        case .precision: return "精确定位 (Precision)"
        case .text: return "文本选择 (Text/IBeam)"
        case .handwriting: return "手写输入 (Handwriting)"
        case .unavailable: return "禁止/不可用 (Unavailable)"
        case .vertical: return "垂直缩放 (Vertical)"
        case .horizontal: return "水平缩放 (Horizontal)"
        case .diagonal1: return "对角缩放 1 (Diagonal 1)"
        case .diagonal2: return "对角缩放 2 (Diagonal 2)"
        case .move: return "移动 (Move)"
        case .alternate: return "候选选择 (Alternate)"
        case .link: return "链接选择 (Link/Hand)"
        case .person: return "人员/定位 (Person)"
        case .pin: return "图钉/标记 (Pin)"
        case .custom: return "自定义光标 (Custom)"
        }
    }

    public var macIdentifiers: [String] {
        switch self {
        case .arrow:
            return ["com.apple.coregraphics.Arrow", "com.apple.cursor.0", "com.apple.coregraphics.ArrowS"]
        case .help:
            return ["com.apple.cursor.40"]
        case .working:
            return ["com.apple.coregraphics.Wait", "com.apple.cursor.4"]
        case .busy:
            return ["com.apple.coregraphics.Wait", "com.apple.cursor.4"]
        case .precision:
            return ["com.apple.cursor.7", "com.apple.cursor.8"]
        case .text:
            return ["com.apple.coregraphics.IBeam", "com.apple.cursor.1", "com.apple.coregraphics.IBeamS"]
        case .handwriting:
            return ["com.apple.cursor.10"]
        case .unavailable:
            return ["com.apple.cursor.3"]
        case .vertical:
            return ["com.apple.cursor.23", "com.apple.cursor.32"]
        case .horizontal:
            return ["com.apple.cursor.19", "com.apple.cursor.28"]
        case .diagonal1:
            return ["com.apple.cursor.34"]
        case .diagonal2:
            return ["com.apple.cursor.30"]
        case .move:
            return ["com.apple.coregraphics.Move"]
        case .alternate:
            return ["com.apple.cursor.21", "com.apple.cursor.22"]
        case .link:
            return ["com.apple.cursor.2", "com.apple.cursor.13"]
        case .person:
            return ["com.apple.cursor.9"]
        case .pin:
            return ["com.apple.cursor.12"]
        case .custom:
            return []
        }
    }

    public static func match(fromFileName filename: String) -> CursorRole {
        let name = filename.lowercased()
        if name.contains("normal") || name.contains("pointer") || name.contains("arrow") { return .arrow }
        if name.contains("help") { return .help }
        if name.contains("working") || name.contains("appstarting") { return .working }
        if name.contains("busy") || name.contains("wait") { return .busy }
        if name.contains("precision") || name.contains("cross") { return .precision }
        if name.contains("text") || name.contains("ibeam") { return .text }
        if name.contains("handwriting") || name.contains("pen") { return .handwriting }
        if name.contains("unavailable") || name.contains("no") || name.contains("forbidden") { return .unavailable }
        if name.contains("vertical") || name.contains("vert") || name.contains("sizens") { return .vertical }
        if name.contains("horizontal") || name.contains("horz") || name.contains("sizewe") { return .horizontal }
        if name.contains("diagonal1") || name.contains("dgn1") || name.contains("sizenwse") { return .diagonal1 }
        if name.contains("diagonal2") || name.contains("dgn2") || name.contains("sizenesw") { return .diagonal2 }
        if name.contains("move") || name.contains("sizeall") { return .move }
        if name.contains("alternate") || name.contains("uparrow") { return .alternate }
        if name.contains("link") || name.contains("hand") { return .link }
        if name.contains("person") { return .person }
        if name.contains("pin") { return .pin }
        return .custom
    }
}

public struct CursorFrame: Identifiable, Sendable {
    public let id = UUID()
    public let image: NSImage
    public let hotspot: CGPoint
    public let duration: Double
    public let size: CGSize

    public init(image: NSImage, hotspot: CGPoint, duration: Double, size: CGSize) {
        self.image = image
        self.hotspot = hotspot
        self.duration = duration
        self.size = size
    }
}

public class CursorItem: Identifiable, ObservableObject {
    public let id = UUID()
    public let role: CursorRole
    public let name: String
    public let sourceFileName: String
    public let isAnimated: Bool
    public let frames: [CursorFrame]
    public let frameRate: Double
    public let hotspot: CGPoint
    public let size: CGSize

    public init(
        role: CursorRole,
        name: String,
        sourceFileName: String,
        isAnimated: Bool,
        frames: [CursorFrame],
        frameRate: Double,
        hotspot: CGPoint,
        size: CGSize
    ) {
        self.role = role
        self.name = name
        self.sourceFileName = sourceFileName
        self.isAnimated = isAnimated
        self.frames = frames
        self.frameRate = frameRate
        self.hotspot = hotspot
        self.size = size
    }

    public var previewImage: NSImage {
        frames.first?.image ?? NSImage()
    }
}

public class CursorScheme: Identifiable, ObservableObject {
    public let id = UUID()
    @Published public var name: String
    @Published public var author: String
    @Published public var sourceDirectory: URL?
    @Published public var isAnimatedScheme: Bool
    @Published public var items: [CursorItem] = []

    public init(
        name: String,
        author: String = "Windows to Mac Converter",
        sourceDirectory: URL? = nil,
        isAnimatedScheme: Bool = false,
        items: [CursorItem] = []
    ) {
        self.name = name
        self.author = author
        self.sourceDirectory = sourceDirectory
        self.isAnimatedScheme = isAnimatedScheme
        self.items = items
    }
}
