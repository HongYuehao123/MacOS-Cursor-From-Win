import Foundation

public struct INFParser {
    public struct SchemeInfo {
        public let schemeName: String
        public let roleFiles: [CursorRole: String]
    }

    public static func parse(content: String) -> SchemeInfo {
        var schemeName = "Windows Cursor Scheme"
        var stringsDict: [String: String] = [:]
        var inStringsSection = false

        let lines = content.components(separatedBy: .newlines)
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line.hasPrefix(";") || line.hasPrefix("#") { continue }

            if line.hasPrefix("[") && line.hasSuffix("]") {
                let section = line.dropFirst().dropLast().trimmingCharacters(in: .whitespaces).lowercased()
                inStringsSection = (section == "strings")
                continue
            }

            if inStringsSection {
                let parts = line.components(separatedBy: "=")
                if parts.count >= 2 {
                    let key = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
                    var val = parts[1...].joined(separator: "=").trimmingCharacters(in: .whitespaces)
                    val = val.trimmingCharacters(in: CharacterSet(charactersIn: "\"'\t "))
                    stringsDict[key] = val
                    if key == "scheme_name" {
                        schemeName = val
                    }
                }
            }
        }

        var roleFiles: [CursorRole: String] = [:]
        for (key, fileName) in stringsDict {
            if let role = roleFromINFKey(key) {
                roleFiles[role] = fileName
            }
        }

        return SchemeInfo(schemeName: schemeName, roleFiles: roleFiles)
    }

    public static func parse(url: URL) throws -> SchemeInfo {
        let content: String
        do {
            content = try String(contentsOf: url, encoding: .utf8)
        } catch {
            content = try String(contentsOf: url, encoding: .windowsCP1252)
        }
        return parse(content: content)
    }

    public static func roleFromINFKey(_ key: String) -> CursorRole? {
        switch key.lowercased() {
        case "pointer", "arrow": return .arrow
        case "help": return .help
        case "working", "appstarting": return .working
        case "busy", "wait": return .busy
        case "precision", "crosshair", "precisionhair": return .precision
        case "text", "ibeam": return .text
        case "hand", "nwpen": return .handwriting
        case "unavailable", "no": return .unavailable
        case "vert", "sizens": return .vertical
        case "horz", "sizewe": return .horizontal
        case "dgn1", "sizenwse": return .diagonal1
        case "dgn2", "sizenesw": return .diagonal2
        case "move", "sizeall": return .move
        case "alternate", "uparrow": return .alternate
        case "link": return .link
        case "person": return .person
        case "pin": return .pin
        default: return nil
        }
    }
}
