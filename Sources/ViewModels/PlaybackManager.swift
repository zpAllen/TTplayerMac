//
//  PlaybackManager.swift
//  TTPlayer for macOS
//
//  播放管理器（集成播放器和播放列表）
//

import Foundation
import Combine
import AppKit
import MediaPlayer

/// 播放管理器
class PlaybackManager: ObservableObject {
    // MARK: - Published Properties

    @Published var player: EnhancedAudioPlayer
    @Published var playlists: [Playlist]
    @Published var playlist: Playlist
    @Published var lyricSync: LyricSyncEngine
    @Published var equalizer: AudioEqualizer

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var playlistEvents: AnyCancellable?
    private let lyricSearchEngine = LyricSearchEngine()
    private var didRestore = false
    private var isRestoring = false

    // MARK: - Initialization

    init() {
        let player = EnhancedAudioPlayer()
        self.player = player
        let initial = Playlist(name: "默认列表")
        self.playlists = [initial]
        self.playlist = initial
        self.lyricSync = LyricSyncEngine()
        // 复用播放器内接入音频链的均衡器实例，避免 UI 绑定到孤儿实例
        self.equalizer = player.equalizer

        setupObservers()
        observePlaylist(initial)
        setupRemoteCommands()
    }

    /// 启动时恢复均衡器曲线和上次的播放列表
    func restoreIfNeeded() {
        guard !didRestore else { return }
        didRestore = true
        isRestoring = true

        equalizer.loadSettings()
        if UserDefaults.standard.object(forKey: "audio.replayGain") != nil {
            player.setReplayGainEnabled(UserDefaults.standard.bool(forKey: "audio.replayGain"))
        }

        let restored = loadLibrary()
        playlists = restored.lists
        playlist = restored.current
        observePlaylist(playlist)

        isRestoring = false
        persist()

        Task {
            await enrichMetadata()
        }
    }

    /// 记住全部列表、当前列表、播放模式、均衡器和音量增益
    func persist() {
        guard didRestore, !isRestoring else { return }
        let library = SavedLibrary(
            currentID: playlist.id,
            lists: playlists.map { list in
                SavedPlaylist(
                    id: list.id,
                    name: list.name,
                    paths: list.tracks.map(\.url.path),
                    currentIndex: list.currentIndex,
                    playMode: list.playMode.rawValue
                )
            }
        )
        if let data = try? JSONEncoder().encode(library) {
            UserDefaults.standard.set(data, forKey: "library.v1")
        }
        UserDefaults.standard.set(playlist.tracks.map(\.url.path), forKey: "playlist.paths")
        UserDefaults.standard.set(playlist.playMode.rawValue, forKey: "playlist.mode")
        UserDefaults.standard.set(player.replayGainEnabled, forKey: "audio.replayGain")
        equalizer.saveSettings()
    }

    func selectPlaylist(id: UUID) {
        guard let next = playlists.first(where: { $0.id == id }) else { return }
        playlist = next
        observePlaylist(next)
        persist()
    }

    func createPlaylist(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let list = Playlist(name: trimmed.isEmpty ? "未命名列表" : trimmed)
        playlists.append(list)
        selectPlaylist(id: list.id)
    }

    func deletePlaylist(id: UUID) {
        guard playlists.count > 1 else { return }
        playlists.removeAll { $0.id == id }
        if playlist.id == id, let first = playlists.first {
            playlist = first
            observePlaylist(first)
        }
        persist()
    }

    func setReplayGainEnabled(_ enabled: Bool) {
        player.setReplayGainEnabled(enabled)
        persist()
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
                playlist.tracks[index].replayGainDB = loaded.replayGainDB
                playlist.tracks[index].replayPeak = loaded.replayPeak
                if var current = player.currentTrack, current.url == track.url {
                    current.artworkData = loaded.artworkData
                    current.title = loaded.title
                    current.artist = loaded.artist
                    current.album = loaded.album
                    current.replayGainDB = loaded.replayGainDB
                    current.replayPeak = loaded.replayPeak
                    player.currentTrack = current
                    player.updateReplayGain(db: loaded.replayGainDB, peak: loaded.replayPeak)
                    updateNowPlaying()
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

        // 子对象的变化要冒泡，主窗口才能跟着歌词和列表刷新。
        // 列表实例会切换，单独在 observePlaylist 里订阅。
        for object in [lyricSync.objectWillChange, equalizer.objectWillChange] {
            object
                .sink { [weak self] _ in
                    self?.objectWillChange.send()
                }
                .store(in: &cancellables)
        }

        // 播放器只冒泡真正影响布局的状态。currentTime 每秒变十次，
        // 转发出去会让整个主窗口跟着重算；时间显示由各自的视图直接观察播放器。
        let playerChanges: [AnyPublisher<Void, Never>] = [
            player.$isPlaying.map { _ in () }.eraseToAnyPublisher(),
            player.$duration.map { _ in () }.eraseToAnyPublisher(),
            player.$volume.map { _ in () }.eraseToAnyPublisher(),
            player.$isMuted.map { _ in () }.eraseToAnyPublisher(),
            player.$currentTrack.map { _ in () }.eraseToAnyPublisher(),
            player.$replayGainEnabled.map { _ in () }.eraseToAnyPublisher()
        ]
        Publishers.MergeMany(playerChanges)
            .dropFirst(playerChanges.count)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        player.$isPlaying
            .sink { [weak self] _ in
                self?.updateNowPlaying()
            }
            .store(in: &cancellables)

        player.$currentTrack
            .sink { [weak self] _ in
                self?.updateNowPlaying()
            }
            .store(in: &cancellables)

        Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard self?.player.isPlaying == true else { return }
                self?.updateNowPlaying()
            }
            .store(in: &cancellables)
    }

    private func observePlaylist(_ playlist: Playlist) {
        playlistEvents = playlist.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
            DispatchQueue.main.async {
                self?.persist()
            }
        }
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
        player.playTrack(track)
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
        updateNowPlaying()
    }

    // MARK: - 播放列表文件

    func exportPlaylist(to url: URL) throws {
        var lines = ["#EXTM3U"]
        for track in playlist.tracks {
            let seconds = Int(track.duration.rounded())
            lines.append("#EXTINF:\(seconds),\(track.displayName)")
            lines.append(track.url.path)
        }
        try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    func importPlaylistFile(from url: URL) async {
        guard let text = Self.playlistText(at: url) else { return }
        let files = Self.playlistEntries(in: text, relativeTo: url.deletingLastPathComponent())
        await importTracks(from: files)
    }

    // MARK: - 正在播放

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.togglePlayPauseCommand.isEnabled = true
        center.nextTrackCommand.isEnabled = true
        center.previousTrackCommand.isEnabled = true
        center.changePlaybackPositionCommand.isEnabled = true

        center.playCommand.addTarget { [weak self] _ in
            self?.performOnMain { if self?.player.isPlaying == false { self?.togglePlayPause() } }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.performOnMain { if self?.player.isPlaying == true { self?.player.pause() } }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.performOnMain { self?.togglePlayPause() }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.performOnMain { self?.playNext() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.performOnMain { self?.playPrevious() }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let position = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.performOnMain { self?.player.seek(to: position.positionTime) }
            return .success
        }
    }

    private func performOnMain(_ body: @escaping () -> Void) {
        if Thread.isMainThread {
            body()
        } else {
            DispatchQueue.main.async(execute: body)
        }
    }

    private func updateNowPlaying() {
        guard let track = player.currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: player.currentTime,
            MPMediaItemPropertyPlaybackDuration: player.duration,
            MPNowPlayingInfoPropertyPlaybackRate: player.isPlaying ? 1.0 : 0.0
        ]
        if let artist = track.artist, !artist.isEmpty {
            info[MPMediaItemPropertyArtist] = artist
        }
        if let album = track.album, !album.isEmpty {
            info[MPMediaItemPropertyAlbumTitle] = album
        }
        if let data = track.artworkData, let image = NSImage(data: data) {
            let size = image.size
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: size) { _ in image }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: - 列表存档

    private func loadLibrary() -> (lists: [Playlist], current: Playlist) {
        if let data = UserDefaults.standard.data(forKey: "library.v1"),
           let library = try? JSONDecoder().decode(SavedLibrary.self, from: data),
           !library.lists.isEmpty {
            let lists = library.lists.map(Self.makePlaylist)
            let current = lists.first { $0.id == library.currentID } ?? lists[0]
            return (lists, current)
        }

        let list = Playlist(name: "默认列表")
        if let modeName = UserDefaults.standard.string(forKey: "playlist.mode"),
           let mode = PlayMode(rawValue: modeName) {
            list.playMode = mode
        }
        let paths = UserDefaults.standard.stringArray(forKey: "playlist.paths") ?? []
        list.add(tracks: Self.tracks(from: paths))
        return ([list], list)
    }

    private static func makePlaylist(_ saved: SavedPlaylist) -> Playlist {
        let list = Playlist(id: saved.id, name: saved.name)
        if let mode = PlayMode(rawValue: saved.playMode) {
            list.playMode = mode
        }
        list.add(tracks: tracks(from: saved.paths))
        if !list.tracks.isEmpty {
            list.currentIndex = min(max(0, saved.currentIndex), list.tracks.count - 1)
        }
        return list
    }

    private static func tracks(from paths: [String]) -> [Track] {
        paths.compactMap { path in
            guard FileManager.default.fileExists(atPath: path) else { return nil }
            let url = URL(fileURLWithPath: path)
            return Track(url: url, title: url.deletingPathExtension().lastPathComponent)
        }
    }

    private static func playlistText(at url: URL) -> String? {
        if let text = try? String(contentsOf: url, encoding: .utf8) { return text }
        let gb18030 = String.Encoding(
            rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
            )
        )
        return try? String(contentsOf: url, encoding: gb18030)
    }

    private static func playlistEntries(in text: String, relativeTo base: URL) -> [URL] {
        text.split(whereSeparator: \.isNewline).compactMap { raw in
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\\", with: "/")
            guard !line.isEmpty, !line.hasPrefix("#") else { return nil }
            if line.hasPrefix("file://"), let url = URL(string: line) {
                return url
            }
            if line.hasPrefix("/") {
                return URL(fileURLWithPath: line)
            }
            return base.appendingPathComponent(line)
        }
    }
}

private struct SavedPlaylist: Codable {
    var id: UUID
    var name: String
    var paths: [String]
    var currentIndex: Int
    var playMode: String
}

private struct SavedLibrary: Codable {
    var currentID: UUID
    var lists: [SavedPlaylist]
}
