//
//  SkinDocument.swift
//  TTPlayer for macOS
//
//  千千静听皮肤：Skin.xml 里的窗口和控件。坐标原点在左上，右下角是开区间。
//

import AppKit

struct SkinDocument {
    var name: String
    var transparent: NSColor
    var player: SkinWindowSpec?
}

struct SkinWindowSpec {
    var imageName: String
    var controls: [SkinControlSpec]
}

enum SkinControlSpec {
    case button(id: String, rect: CGRect, imageName: String)
    case progress(rect: CGRect, thumb: String?, fill: String?, groove: String?)
    case volume(rect: CGRect, fill: String?, vertical: Bool)
    case label(id: String, rect: CGRect, color: NSColor, fontSize: CGFloat, align: NSTextAlignment)
    case led(rect: CGRect, imageName: String)
    case visual(rect: CGRect)
}

enum SkinXMLParser {
    static func parse(_ data: Data) -> SkinDocument? {
        let source = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .init(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))))
            ?? ""
        guard !source.isEmpty, let cleaned = repair(source).data(using: .utf8) else { return nil }
        let delegate = Delegate()
        let parser = XMLParser(data: cleaned)
        parser.delegate = delegate
        guard parser.parse(), delegate.document.player != nil else { return nil }
        return delegate.document
    }

    /// 原版 Skin.xml 里有未加引号的属性，系统 XML 解析器会整份拒绝。
    private static func repair(_ source: String) -> String {
        source.replacingOccurrences(
            of: #"(\s)([A-Za-z_][\w:.-]*)=(?!")([^"'\s>]+)"#,
            with: #"$1$2="$3""#,
            options: .regularExpression
        )
    }
}

private final class Delegate: NSObject, XMLParserDelegate {
    var document = SkinDocument(name: "", transparent: NSColor(srgbRed: 1, green: 0, blue: 1, alpha: 1), player: nil)
    private var windowName: String?
    private var imageName = ""
    private var controls: [SkinControlSpec] = []

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes: [String: String] = [:]
    ) {
        if elementName == "skin" {
            document.name = attributes["name"] ?? ""
            if let color = Self.color(attributes["transparent_color"]) {
                document.transparent = color
            }
            return
        }

        if elementName == "player_window" {
            windowName = elementName
            imageName = attributes["image"] ?? ""
            controls = []
            return
        }

        guard windowName != nil else { return }
        guard let rect = Self.rect(attributes["position"]) else { return }

        switch elementName {
        case "progress":
            controls.append(.progress(
                rect: rect,
                thumb: attributes["thumb_image"],
                fill: attributes["fill_image"],
                groove: attributes["fill_image2"]
            ))
        case "volume":
            controls.append(.volume(
                rect: rect,
                fill: attributes["fill_image"],
                vertical: attributes["vertical"] == "true"
            ))
        case "info", "stereo", "status":
            controls.append(.label(
                id: elementName,
                rect: rect,
                color: Self.color(attributes["color"]) ?? .white,
                fontSize: CGFloat(Double(attributes["font_size"] ?? "") ?? 13),
                align: Self.align(attributes["align"])
            ))
        case "led":
            if let name = attributes["image"] {
                controls.append(.led(rect: rect, imageName: name))
            }
        case "visual":
            controls.append(.visual(rect: rect))
        default:
            if let name = attributes["image"], !name.isEmpty {
                controls.append(.button(id: elementName, rect: rect, imageName: name))
            }
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard elementName == windowName else { return }
        let spec = SkinWindowSpec(imageName: imageName, controls: controls)
        if elementName == "player_window" {
            document.player = spec
        }
        windowName = nil
    }

    private static func rect(_ text: String?) -> CGRect? {
        guard let text else { return nil }
        let parts = text.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 4 else { return nil }
        return CGRect(x: parts[0], y: parts[1], width: parts[2] - parts[0], height: parts[3] - parts[1])
    }

    private static func color(_ text: String?) -> NSColor? {
        guard var text else { return nil }
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6, let value = UInt32(text, radix: 16) else { return nil }
        return NSColor(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }

    private static func align(_ text: String?) -> NSTextAlignment {
        switch text {
        case "right": return .right
        case "center": return .center
        default: return .left
        }
    }
}
