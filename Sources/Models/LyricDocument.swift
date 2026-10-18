//
//  LyricDocument.swift
//  TTPlayer for macOS
//
//  LRC 歌词文档模型
//

import Foundation

/// LRC 元数据
struct LRCMetadata: Codable {
    var title: String?
    var artist: String?
    var album: String?
    var creator: String?      // [by:] 标签
    var offset: TimeInterval = 0  // [offset:] 毫秒偏移
}

/// LRC 歌词行
struct LRCLine: Identifiable, Codable {
    let id = UUID()
    let timestamp: TimeInterval  // 秒（非毫秒）
    let text: String

    enum CodingKeys: String, CodingKey {
        case timestamp, text
    }
}

/// LRC 歌词文档
class LyricDocument: ObservableObject {
    @Published var metadata = LRCMetadata()
    @Published private(set) var lines: [LRCLine] = []

    /// 解析 LRC 文件
    /// - Parameter url: LRC 文件 URL
    func parse(url: URL) throws {
        let data = try Data(contentsOf: url)
        if let content = String(data: data, encoding: .utf8) {
            parse(content: content)
            return
        }
        let gb18030 = String.Encoding(
            rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
            )
        )
        guard let content = String(data: data, encoding: gb18030) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        parse(content: content)
    }

    /// 解析 LRC 内容
    /// - Parameter content: LRC 文本内容
    func parse(content: String) {
        lines.removeAll()

        let contentLines = content.components(separatedBy: .newlines)

        for line in contentLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // 解析元数据标签
            if parseMetadata(line: trimmed) {
                continue
            }

            // 解析时间标签
            parseLyricLine(line: trimmed)
        }

        // 按时间排序
        lines.sort { $0.timestamp < $1.timestamp }

        // 没有时间轴的内嵌歌词，整段作为一句显示
        if lines.isEmpty {
            let plain = contentLines
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            if !plain.isEmpty {
                lines = [LRCLine(timestamp: 0, text: plain.joined(separator: "\n"))]
            }
        }
    }

    /// 解析元数据标签
    private func parseMetadata(line: String) -> Bool {
        // [ti:标题]
        if let range = line.range(of: #"\[ti:(.*?)\]"#, options: .regularExpression) {
            metadata.title = extractValue(from: line, range: range)
            return true
        }

        // [ar:艺术家]
        if let range = line.range(of: #"\[ar:(.*?)\]"#, options: .regularExpression) {
            metadata.artist = extractValue(from: line, range: range)
            return true
        }

        // [al:专辑]
        if let range = line.range(of: #"\[al:(.*?)\]"#, options: .regularExpression) {
            metadata.album = extractValue(from: line, range: range)
            return true
        }

        // [by:制作者]
        if let range = line.range(of: #"\[by:(.*?)\]"#, options: .regularExpression) {
            metadata.creator = extractValue(from: line, range: range)
            return true
        }

        // [offset:毫秒]
        if let range = line.range(of: #"\[offset:(\d+)\]"#, options: .regularExpression) {
            let value = extractValue(from: line, range: range)
            if let offset = Double(value) {
                metadata.offset = offset / 1000.0  // 毫秒转秒
            }
            return true
        }

        return false
    }

    /// 解析歌词行
    private func parseLyricLine(line: String) {
        // 正则表达式：[mm:ss.xx] 或 [mm:ss]
        let pattern = #"\[(\d+):(\d+\.?\d*)\](.+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

        let nsLine = line as NSString
        let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsLine.length))

        for match in matches {
            guard match.numberOfRanges == 4 else { continue }

            let minutesStr = nsLine.substring(with: match.range(at: 1))
            let secondsStr = nsLine.substring(with: match.range(at: 2))
            let text = nsLine.substring(with: match.range(at: 3)).trimmingCharacters(in: .whitespaces)

            guard let minutes = Double(minutesStr),
                  let seconds = Double(secondsStr) else {
                continue
            }

            // 转换为秒，加上偏移
            let timestamp = minutes * 60 + seconds + metadata.offset

            lines.append(LRCLine(timestamp: timestamp, text: text))
        }
    }

    /// 从字符串中提取标签值
    private func extractValue(from string: String, range: Range<String.Index>) -> String {
        let matched = String(string[range])
        // 提取 [xxx:值] 中的 "值" 部分
        if let colonIndex = matched.firstIndex(of: ":"),
           let bracketIndex = matched.lastIndex(of: "]") {
            let start = matched.index(after: colonIndex)
            return String(matched[start..<bracketIndex])
        }
        return ""
    }

    /// 根据时间获取当前歌词行
    /// - Parameter time: 当前播放时间（秒）
    /// - Returns: 对应的歌词行，如果没有则返回 nil
    func currentLine(at time: TimeInterval) -> LRCLine? {
        return lines.last { $0.timestamp <= time }
    }

    /// 根据时间获取当前歌词行索引
    func currentLineIndex(at time: TimeInterval) -> Int? {
        guard let line = currentLine(at: time) else { return nil }
        return lines.firstIndex { $0.id == line.id }
    }
}
