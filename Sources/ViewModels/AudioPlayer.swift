//
//  AudioPlayer.swift
//  TTPlayer for macOS
//
//  音频播放引擎
//

import Foundation
import AVFoundation
import Combine

/// 音频播放器
class AudioPlayer: ObservableObject {
    // MARK: - Published Properties

    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var volume: Float = 0.8
    @Published var isMuted = false
    @Published var currentTrack: Track?

    // MARK: - Private Properties

    private var player: AVPlayer?
    private var currentItem: AVPlayerItem?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        setupObservers()
    }

    deinit {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
    }

    // MARK: - Playback Control

    /// 加载曲目
    func load(track: Track) {
        currentTrack = track

        let asset = AVAsset(url: track.url)
        currentItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: currentItem)

        // 设置音量
        player?.volume = volume

        setupTimeObserver()
        setupItemObservers()

        // 获取时长
        Task {
            if let duration = try? await asset.load(.duration) {
                await MainActor.run {
                    self.duration = duration.seconds
                }
            }
        }
    }

    /// 播放
    func play() {
        player?.play()
        isPlaying = true
    }

    /// 暂停
    func pause() {
        player?.pause()
        isPlaying = false
    }

    /// 停止
    func stop() {
        player?.pause()
        player?.seek(to: .zero)
        isPlaying = false
        currentTime = 0
    }

    /// 播放/暂停切换
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    /// 跳转到指定时间
    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 1000)
        player?.seek(to: cmTime) { [weak self] finished in
            if finished {
                self?.currentTime = time
            }
        }
    }

    // MARK: - Volume Control

    /// 设置音量（0.0 - 1.0）
    func setVolume(_ newVolume: Float) {
        volume = max(0, min(1, newVolume))
        player?.volume = isMuted ? 0 : volume
    }

    /// 静音切换
    func toggleMute() {
        isMuted.toggle()
        player?.volume = isMuted ? 0 : volume
    }

    // MARK: - Private Methods

    /// 设置观察者
    private func setupObservers() {
        // 监听音量变化
        $volume
            .sink { [weak self] newVolume in
                guard let self = self, !self.isMuted else { return }
                self.player?.volume = newVolume
            }
            .store(in: &cancellables)
    }

    /// 设置时间观察器
    private func setupTimeObserver() {
        // 移除旧的观察器
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }

        // 每 0.1 秒更新一次
        let interval = CMTime(value: 1, timescale: 10)
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            self?.currentTime = time.seconds
        }
    }

    /// 设置播放项观察器
    private func setupItemObservers() {
        // 监听播放完成
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.handleTrackEnd()
        }

        // 监听播放失败
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: currentItem,
            queue: .main
        ) { [weak self] notification in
            self?.handlePlaybackError(notification)
        }
    }

    /// 处理曲目播放结束
    private func handleTrackEnd() {
        isPlaying = false
        // 发送通知，让播放列表处理下一曲
        NotificationCenter.default.post(name: .trackDidFinishPlaying, object: nil)
    }

    /// 处理播放错误
    private func handlePlaybackError(_ notification: Notification) {
        isPlaying = false
        print("播放错误: \(notification)")
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let trackDidFinishPlaying = Notification.Name("trackDidFinishPlaying")
}
