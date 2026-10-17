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

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private let lyricSearchEngine = LyricSearchEngine()

    // MARK: - Initialization

    init() {
        self.player = EnhancedAudioPlayer()
        self.playlist = Playlist(name: "默认列表")
        self.lyricSync = LyricSyncEngine()
        self.playlistManager = PlaylistManager()

        setupObservers()
    }

    // MARK: - Setup

    private func setupObservers() {
        // 歌曲播放完成自动播放下一曲
        NotificationCenter.default.publisher(for: .trackDidFinishPlaying)
            .sink { [weak self] _ in
                self?.playNext()
            }
            .store(in: &cancellables)

        // 连接歌词同步
        lyricSync.connect(to: player)
    }

    // MARK: - Playback Control

    /// 播放指定曲目
    func play(track: Track) {
        player.load(track: track)
        player.play()

        // 自动加载歌词
        loadLyrics(for: track)
    }

    /// 播放下一曲
    func playNext() {
        if let next = playlist.next() {
            play(track: next)
        }
    }

    /// 播放上一曲
    func playPrevious() {
        if let previous = playlist.previous() {
            play(track: previous)
        }
    }

    // MARK: - Track Management

    /// 添加曲目
    func addTrack(_ track: Track) {
        playlist.add(track: track)

        // 如果当前没有播放，自动播放第一首
        if player.currentTrack == nil {
            play(track: track)
        }
    }

    /// 导入曲目
    func importTracks(from urls: [URL]) async {
        for url in urls {
            if let track = await Track.from(url: url) {
                await MainActor.run {
                    addTrack(track)
                }
            }
        }
    }

    // MARK: - Lyrics

    private func loadLyrics(for track: Track) {
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
}
