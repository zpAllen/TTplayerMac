//
//  LyricSearchEngine.swift
//  TTPlayer for macOS
//
//  歌词搜索引擎
//

import Foundation

/// 歌词搜索引擎
class LyricSearchEngine {
    // MARK: - Local Search

    /// 搜索本地歌词文件
    func searchLocalLyrics(for track: Track) -> [URL] {
        var results: [URL] = []

        // 1. 同目录搜索
        if let sameDir = searchInSameDirectory(as: track.url, for: track) {
            results.append(contentsOf: sameDir)
        }

        // 2. 歌词文件夹搜索
        if let lyricsFolder = getLyricsFolder() {
            if let folderResults = searchInDirectory(lyricsFolder, for: track) {
                results.append(contentsOf: folderResults)
            }
        }

        return results
    }

    /// 搜索同目录下的歌词
    private func searchInSameDirectory(as url: URL, for track: Track) -> [URL]? {
        let directory = url.deletingLastPathComponent()
        return searchInDirectory(directory, for: track)
    }

    /// 在指定目录搜索歌词
    private func searchInDirectory(_ directory: URL, for track: Track) -> [URL]? {
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else {
            return nil
        }

        var results: [URL] = []

        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension.lowercased() == "lrc" {
                let score = scoreMatch(lyricFile: fileURL, track: track)
                if score > 0 {
                    results.append(fileURL)
                }
            }
        }

        // 按评分排序（高分在前）
        results.sort { url1, url2 in
            scoreMatch(lyricFile: url1, track: track) > scoreMatch(lyricFile: url2, track: track)
        }

        return results
    }

    /// 评分匹配度（0-9分）
    func scoreMatch(lyricFile: URL, track: Track) -> Int {
        let filename = lyricFile.deletingPathExtension().lastPathComponent.lowercased()
        let title = track.title.lowercased()
        let artist = (track.artist ?? "").lowercased()

        var score = 0

        // 完全匹配文件名 +9
        if filename == "\(artist) - \(title)" {
            return 9
        }

        // 艺术家匹配 +3
        if !artist.isEmpty && filename.contains(artist) {
            score += 3
        }

        // 标题匹配 +6
        if filename.contains(title) {
            score += 6
        }

        return min(score, 9)
    }

    // MARK: - Lyrics Folder

    /// 获取歌词文件夹路径
    private func getLyricsFolder() -> URL? {
        let fileManager = FileManager.default

        // 1. 用户配置的歌词文件夹
        if let customPath = UserDefaults.standard.string(forKey: "lyrics.folder") {
            return URL(fileURLWithPath: customPath)
        }

        // 2. 默认歌词文件夹（~/Music/Lyrics）
        if let musicDir = fileManager.urls(for: .musicDirectory, in: .userDomainMask).first {
            let lyricsDir = musicDir.appendingPathComponent("Lyrics")

            // 创建目录（如果不存在）
            try? fileManager.createDirectory(at: lyricsDir, withIntermediateDirectories: true)

            return lyricsDir
        }

        return nil
    }

    /// 设置歌词文件夹
    func setLyricsFolder(_ url: URL) {
        UserDefaults.standard.set(url.path, forKey: "lyrics.folder")
    }

    // MARK: - Auto Load

    /// 自动加载歌词（异步）
    func autoLoadLyrics(for track: Track) async -> LyricDocument? {
        let results = searchLocalLyrics(for: track)

        guard let bestMatch = results.first else {
            return nil
        }

        let document = LyricDocument()
        try? document.parse(url: bestMatch)
        return document
    }
}
