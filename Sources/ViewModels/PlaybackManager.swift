//
//  PlaybackManager.swift
//  TTPlayer for macOS
//
//  播放管理器（集成播放器和播放列表）
//

import Foundation
import Combine

/// 播放管理器
class PlaybackManager: ObservableObject {
    // MARK: - Published Properties

    @Published var player: EnhancedAudioPlayer
    @Published var playlist: Playlist
    @Published var lyricSync: LyricSyncEngine
    @Published var playlistManager: PlaylistManager
    @Published var equalizer: AudioEqualizer

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private let lyricSearchEngine = LyricSearchEngine()

    // MARK: - Initialization

    init() {
        let player = EnhancedAudioPlayer()
        self.player = player
        self.playlist = Playlist(name: "默认列表")
        self.lyricSync = LyricSyncEngine()
        self.playlistManager = PlaylistManager()
        // 复用播放器内接入音频链的均衡器实例，避免 UI 绑定到孤儿实例
        self.equalizer = player.equalizer

        setupObservers()
    }

    private var didRestore = false

    /// 启动时恢复均衡器曲线和上次的播放列表
    func restoreIfNeeded() {
        guard !didRestore else { return }
        didRestore = true

        equalizer.loadSettings()

        let paths = UserDefaults.standard.stringArray(forKey: "playlist.paths") ?? []
        if let modeName = UserDefaults.standard.string(forKey: "playlist.mode"),
           let mode = PlayMode(rawValue: modeName) {
            playlist.playMode = mode
        }

        let tracks = paths.compactMap { path -> Track? in
            guard FileManager.default.fileExists(atPath: path) else { return nil }
            let url = URL(fileURLWithPath: path)
            return Track(url: url, title: url.deletingPathExtension().lastPathComponent)
        }
        if !tracks.isEmpty {
            playlist.add(tracks: tracks)
        }

        Task {
            await enrichMetadata()
        }
    }

    /// 记住列表、播放模式和均衡器
    func persist() {
        guard didRestore else { return }
        UserDefaults.standard.set(playlist.tracks.map(\.url.path), forKey: "playlist.paths")
        UserDefaults.standard.set(playlist.playMode.rawValue, forKey: "playlist.mode")
        equalizer.saveSettings()
    }

    func cyclePlayMode() {
        playlist.cyclePlayMode()
        persist()
    }

    /// 为当前歌曲指定外部 LRC，并记住，下次播放仍用这个文件
    func useLyricFile(_ url: URL) {
        guard let track = player.currentTrack else { return }
        var map = UserDefaults.standard.dictionary(forKey: "lyrics.customFiles") as? [String: String] ?? [:]
        map[track.url.path] = url.path
        UserDefaults.standard.set(map, forKey: "lyrics.customFiles")
        lyricSync.load(url: url)
    }

    private func enrichMetadata() async {
        let snapshot = playlist.tracks
        for track in snapshot {
            guard let loaded = await Track.from(url: track.url) else { continue }
            await MainActor.run {
                guard let index = playlist.tracks.firstIndex(where: { $0.id == track.id }) else { return }
                playlist.tracks[index].title = loaded.title
                playlist.tracks[index].artist = loaded.artist
                playlist.tracks[index].album = loaded.album
                playlist.tracks[index].duration = loaded.duration
                playlist.tracks[index].artworkData = loaded.artworkData
                if var current = player.currentTrack, current.url == track.url {
                    current.artworkData = loaded.artworkData
                    current.title = loaded.title
                    current.artist = loaded.artist
                    current.album = loaded.album
                    player.currentTrack = current
                }
            }
        }
    }

    // MARK: - Setup

    private func setupObservers() {
        NotificationCenter.default.publisher(for: .trackDidFinishPlaying)
            .sink { [weak self] _ in
                self?.playFinishedTrack()
            }
            .store(in: &cancellables)

        lyricSync.connect(to: player)

        // 子对象的变化要冒泡，主窗口才能跟着进度、歌词和列表刷新
        for object in [player.objectWillChange, playlist.objectWillChange, lyricSync.objectWillChange, equalizer.objectWillChange] {
            object
                .sink { [weak self] _ in
                    self?.objectWillChange.send()
                }
                .store(in: &cancellables)
        }

        playlist.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.persist()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Playback Control

    /// 播放/暂停。有当前曲目就接着播；还没播过就从列表里随机一首。
    func togglePlayPause() {
        if player.isPlaying {
            player.pause()
            return
        }

        if let track = player.currentTrack {
            if player.canResume {
                player.play()
            } else {
                play(track: track)
            }
            return
        }

        guard !playlist.tracks.isEmpty else { return }
        let index = Int.random(in: 0..<playlist.tracks.count)
        playlist.jumpTo(index: index)
        if let track = playlist.currentTrack {
            play(track: track)
        }
    }

    /// 播放指定曲目
    func play(track: Track) {
        player.load(track: track)
        player.play()

        // 自动加载歌词
        loadLyrics(for: track)
    }

    /// 播放下一曲。按钮、菜单和快捷键都按列表向右一首。
    func playNext() {
        if let next = playlist.skip(by: 1) {
            play(track: next)
        }
    }

    /// 播放上一曲。按钮、菜单和快捷键都按列表向左一首。
    func playPrevious() {
        if let previous = playlist.skip(by: -1) {
            play(track: previous)
        }
    }

    /// 当前这首播完。单曲循环会重播，顺序播放到最后一首就停下。
    func playFinishedTrack() {
        guard let next = playlist.trackAfterFinishing() else { return }
        play(track: next)
    }

    // MARK: - Track Management

    /// 添加曲目
    func addTrack(_ track: Track) {
        playlist.add(track: track)

        // 如果当前没有播放，自动播放第一首
        if player.currentTrack == nil {
            play(track: track)
        }
        persist()
    }

    /// 导入曲目。文件直接加入，文件夹则递归加入其中的音频。
    func importTracks(from urls: [URL]) async {
        let files = Self.audioFiles(in: urls)
        for url in files {
            if let track = await Track.from(url: url) {
                await MainActor.run {
                    addTrack(track)
                }
            }
        }
    }

    private static func audioFiles(in urls: [URL]) -> [URL] {
        var files: [URL] = []
        for url in urls {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { continue }
            if isDirectory.boolValue {
                files.append(contentsOf: audioFiles(inDirectory: url))
            } else if FileOpener.audioExtensions.contains(url.pathExtension.lowercased()) {
                files.append(url)
            }
        }
        return files
    }

    private static func audioFiles(inDirectory folder: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var files: [URL] = []
        for case let fileURL as URL in enumerator {
            if FileOpener.audioExtensions.contains(fileURL.pathExtension.lowercased()) {
                files.append(fileURL)
            }
        }
        return files.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
    }

    // MARK: - Lyrics

    private func loadLyrics(for track: Track) {
        if let path = customLyricPath(for: track),
           FileManager.default.fileExists(atPath: path) {
            lyricSync.load(url: URL(fileURLWithPath: path))
            return
        }

        Task {
            if let doc = await lyricSearchEngine.autoLoadLyrics(for: track) {
                await MainActor.run {
                    lyricSync.load(document: doc)
                }
            } else {
                await MainActor.run {
                    lyricSync.clear()
                }
            }
        }
    }

    private func customLyricPath(for track: Track) -> String? {
        let map = UserDefaults.standard.dictionary(forKey: "lyrics.customFiles") as? [String: String]
        return map?[track.url.path]
    }

    // MARK: - Playlist Management

    /// 清空播放列表
    func clearPlaylist() {
        playlist.clear()
        player.stop()
        lyricSync.clear()
        persist()
    }

    // MARK: - Volume Control

    /// 增加音量
    func increaseVolume() {
        player.volume = min(player.volume + 0.1, 1.0)
    }

    /// 减小音量
    func decreaseVolume() {
        player.volume = max(player.volume - 0.1, 0.0)
    }

    /// 静音开关
    func toggleMute() {
        player.toggleMute()
    }
}
