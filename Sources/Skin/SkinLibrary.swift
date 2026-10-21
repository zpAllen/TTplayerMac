//
//  SkinLibrary.swift
//  TTPlayer for macOS
//
//  从 ttpres.dll 或一份解开的皮肤目录载入默认皮肤。位图留在内存，不写进仓库。
//

import AppKit
import Foundation

struct LoadedSkin {
    var name: String
    var source: String
    var player: LoadedWindow
}

struct LoadedWindow {
    var image: NSImage
    var size: CGSize
    var controls: [LoadedControl]
}

enum LoadedControl {
    case button(id: String, rect: CGRect, image: NSImage, states: Int)
    case progress(rect: CGRect, thumb: NSImage?, fill: NSImage?, groove: NSImage?)
    case volume(rect: CGRect, fill: NSImage?, vertical: Bool)
    case label(id: String, rect: CGRect, color: NSColor, fontSize: CGFloat, align: NSTextAlignment)
    case led(rect: CGRect, digits: NSImage)
    case visual(rect: CGRect)
}

final class SkinLibrary: ObservableObject {
    @Published var skin: LoadedSkin?

    func loadDefault() {
        skin = Self.findSkin()
    }

    private static func findSkin() -> LoadedSkin? {
        if let directory = UserDefaults.standard.string(forKey: "skin.directory") {
            let url = URL(fileURLWithPath: directory)
            if let loaded = Self.load(directory: url) {
                print("皮肤 \(loaded.name) \(Int(loaded.player.size.width))×\(Int(loaded.player.size.height)) 来自 \(url.path)")
                return loaded
            }
        }

        if let path = UserDefaults.standard.string(forKey: "skin.dll") {
            let url = URL(fileURLWithPath: path)
            if let loaded = Self.load(dll: url) {
                print("皮肤 \(loaded.name) \(Int(loaded.player.size.width))×\(Int(loaded.player.size.height)) 来自 \(url.path)")
                return loaded
            }
        }

        let candidates = Self.candidateDLLs()
        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            if let loaded = Self.load(dll: url) {
                let line = "皮肤 \(loaded.name) \(Int(loaded.player.size.width))×\(Int(loaded.player.size.height)) 来自 \(url.path)"
                print(line)
                Self.log(line)
                return loaded
            }
            print("找到 \(url.path)，但皮肤解析失败")
            Self.log("解析失败 \(url.path)")
        }

        print("未找到 ttpres.dll。已查找：")
        for url in candidates {
            print("  \(url.path)")
            Self.log("miss \(url.path)")
        }
        return nil
    }

    private static func log(_ line: String) {
        print(line)
    }

    static func load(dll url: URL) -> LoadedSkin? {
        let files = TTPresArchive.extract(from: url)
        guard let xml = files["Skin.xml"] else {
            log("\(url.path) 里没有 Skin.xml")
            return nil
        }
        guard let document = SkinXMLParser.parse(xml) else {
            log("\(url.path) 的 Skin.xml 解析失败")
            return nil
        }
        return make(document: document, files: files, source: url.path)
    }

    static func load(directory: URL) -> LoadedSkin? {
        let xmlURL = directory.appendingPathComponent("Skin.xml")
        guard let xml = try? Data(contentsOf: xmlURL), let document = SkinXMLParser.parse(xml) else { return nil }
        var files: [String: Data] = [:]
        if let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) {
            for name in names {
                let file = directory.appendingPathComponent(name)
                if let data = try? Data(contentsOf: file) {
                    files[name] = data
                }
            }
        }
        return make(document: document, files: files, source: directory.path)
    }

    private static func make(document: SkinDocument, files: [String: Data], source: String) -> LoadedSkin? {
        guard let playerSpec = document.player,
              let player = window(playerSpec, files: files, key: document.transparent) else { return nil }
        return LoadedSkin(name: document.name.isEmpty ? "皮肤" : document.name, source: source, player: player)
    }

    private static func window(_ spec: SkinWindowSpec, files: [String: Data], key: NSColor) -> LoadedWindow? {
        guard let background = image(spec.imageName, files: files, key: key) else {
            log("背景图 \(spec.imageName) 打不开，数据 \(files[spec.imageName]?.count ?? 0) 字节")
            return nil
        }
        var controls: [LoadedControl] = []
        for control in spec.controls {
            switch control {
            case let .button(id, rect, imageName):
                // 右上角只留最小化和关闭。打开、迷你不再画，也不接收点击。
                guard id != "open", id != "minimode" else { continue }
                guard let image = image(imageName, files: files, key: key) else { continue }
                controls.append(.button(id: id, rect: rect, image: image, states: stateCount(image: image, rect: rect)))
            case let .progress(rect, thumb, fill, groove):
                controls.append(.progress(
                    rect: rect,
                    thumb: thumb.flatMap { image($0, files: files, key: key) },
                    fill: fill.flatMap { image($0, files: files, key: key) },
                    groove: groove.flatMap { image($0, files: files, key: key) }
                ))
            case let .volume(rect, fill, vertical):
                controls.append(.volume(
                    rect: rect,
                    fill: fill.flatMap { image($0, files: files, key: key) },
                    vertical: vertical
                ))
            case let .label(id, rect, color, fontSize, align):
                controls.append(.label(id: id, rect: rect, color: color, fontSize: fontSize, align: align))
            case let .led(rect, imageName):
                guard let digits = image(imageName, files: files, key: key) else { continue }
                controls.append(.led(rect: rect, digits: digits))
            case let .visual(rect):
                controls.append(.visual(rect: rect))
            }
        }
        packMinimizeAgainstClose(&controls)
        return LoadedWindow(image: background, size: background.size, controls: controls)
    }

    /// 迷你模式按钮不画之后，最小化要贴到关闭左边，避免右上角中间空一截。
    private static func packMinimizeAgainstClose(_ controls: inout [LoadedControl]) {
        guard let closeIndex = controls.firstIndex(where: {
            if case .button("exit", _, _, _) = $0 { return true }
            return false
        }), let minimizeIndex = controls.firstIndex(where: {
            if case .button("minimize", _, _, _) = $0 { return true }
            return false
        }),
        case let .button(_, closeRect, _, _) = controls[closeIndex],
        case let .button(id, rect, image, states) = controls[minimizeIndex],
        closeRect.minX > rect.maxX + 0.5 else { return }

        let shifted = CGRect(
            x: closeRect.minX - rect.width,
            y: rect.minY,
            width: rect.width,
            height: rect.height
        )
        controls[minimizeIndex] = .button(id: id, rect: shifted, image: image, states: states)
    }

    private static func image(_ name: String, files: [String: Data], key: NSColor) -> NSImage? {
        guard let data = files[name] ?? files[name.lowercased()] else { return nil }
        return BMPDecoder.image(from: data, colorKey: key)
    }

    /// 按钮图通常是等宽的 4 态横条。宽度和点击区域差 1 像素时仍按 4 段切。
    private static func stateCount(image: NSImage, rect: CGRect) -> Int {
        let width = image.size.width
        guard rect.width > 1 else { return 1 }
        for count in [4, 3, 2] {
            let slice = width / CGFloat(count)
            if abs(slice - rect.width) <= 2 || abs(slice - (rect.width - 1)) <= 2 {
                return count
            }
        }
        return 1
    }

    private static func candidateDLLs() -> [URL] {
        var seeds = [URL(fileURLWithPath: FileManager.default.currentDirectoryPath)]
        if let executable = Bundle.main.executableURL?.deletingLastPathComponent() {
            seeds.append(executable)
        }
        // 打包进 app 的皮肤放在 Contents/Resources 里
        if let resources = Bundle.main.resourceURL {
            seeds.append(resources)
        }
        var urls: [URL] = []
        var seen = Set<String>()
        for seed in seeds {
            var cursor = seed.standardizedFileURL
            for _ in 0..<8 {
                let direct = cursor
                    .appendingPathComponent("TTPlayerv5.7.9")
                    .appendingPathComponent("ttpres.dll")
                let sibling = cursor
                    .deletingLastPathComponent()
                    .appendingPathComponent("TTPlayer")
                    .appendingPathComponent("TTPlayerv5.7.9")
                    .appendingPathComponent("ttpres.dll")
                for url in [direct, sibling] where seen.insert(url.path).inserted {
                    urls.append(url)
                }
                if cursor.path == "/" { break }
                cursor.deleteLastPathComponent()
            }
        }
        return urls
    }
}
