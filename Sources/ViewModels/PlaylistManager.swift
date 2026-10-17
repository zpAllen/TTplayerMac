//
//  PlaylistManager.swift
//  TTPlayer for macOS
//
//  播放列表管理器
//

import Foundation
import Combine

/// 播放列表管理器
class PlaylistManager: ObservableObject {
    // MARK: - Published Properties

    @Published var playlists: [Playlist] = []
    @Published var currentPlaylist: Playlist?

    // MARK: - Private Properties

    private let fileManager = FileManager.default
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        loadPlaylists()
    }

    // MARK: - Playlist Management

    /// 创建新播放列表
    func createPlaylist(name: String) {
        let playlist = Playlist(name: name)
        playlists.append(playlist)
        savePlaylists()
    }

    /// 删除播放列表
    func deletePlaylist(at index: Int) {
        guard index >= 0 && index < playlists.count else { return }
        playlists.remove(at: index)
        savePlaylists()
    }

    /// 选择播放列表
    func selectPlaylist(_ playlist: Playlist) {
        currentPlaylist = playlist
    }

    // MARK: - Track Management

    /// 添加曲目到当前播放列表
    func addTrack(_ track: Track) {
        currentPlaylist?.add(track: track)
        savePlaylists()
    }

    /// 添加多个曲目
    func addTracks(_ tracks: [Track]) {
        currentPlaylist?.add(tracks: tracks)
        savePlaylists()
    }

    /// 移除曲目
    func removeTrack(at index: Int) {
        currentPlaylist?.remove(at: index)
        savePlaylists()
    }

    /// 清空当前播放列表
    func clearCurrentPlaylist() {
        currentPlaylist?.clear()
        savePlaylists()
    }

    // MARK: - Persistence

    /// 保存所有播放列表
    func savePlaylists() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(playlists)

            let url = playlistsURL()
            try data.write(to: url)
        } catch {
            print("保存播放列表失败: \(error)")
        }
    }

    /// 加载所有播放列表
    func loadPlaylists() {
        do {
            let url = playlistsURL()
            guard fileManager.fileExists(atPath: url.path) else {
                // 创建默认播放列表
                createDefaultPlaylist()
                return
            }

            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            playlists = try decoder.decode([Playlist].self, from: data)

            // 选择第一个播放列表
            if !playlists.isEmpty {
                currentPlaylist = playlists[0]
            }
        } catch {
            print("加载播放列表失败: \(error)")
            createDefaultPlaylist()
        }
    }

    private func createDefaultPlaylist() {
        let defaultPlaylist = Playlist(name: "默认列表")
        playlists = [defaultPlaylist]
        currentPlaylist = defaultPlaylist
        savePlaylists()
    }

    private func playlistsURL() -> URL {
        let appSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        let appFolder = appSupport.appendingPathComponent("TTPlayer")

        // 创建目录（如果不存在）
        try? fileManager.createDirectory(
            at: appFolder,
            withIntermediateDirectories: true
        )

        return appFolder.appendingPathComponent("Playlists.json")
    }
}

// MARK: - File Import

extension PlaylistManager {
    /// 从文件 URL 数组导入曲目
    func importTracks(from urls: [URL]) async {
        var tracks: [Track] = []

        for url in urls {
            if let track = await Track.from(url: url) {
                tracks.append(track)
            }
        }

        await MainActor.run {
            addTracks(tracks)
        }
    }

    /// 从文件夹导入曲目
    func importFolder(_ url: URL) async {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        var urls: [URL] = []

        for case let fileURL as URL in enumerator {
            // 检查是否是音频文件
            if isAudioFile(fileURL) {
                urls.append(fileURL)
            }
        }

        await importTracks(from: urls)
    }

    private func isAudioFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["mp3", "m4a", "aac", "wav", "aiff", "flac", "ape", "ogg"].contains(ext)
    }
}
