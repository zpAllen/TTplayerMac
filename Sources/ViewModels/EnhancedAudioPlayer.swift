//
//  EnhancedAudioPlayer.swift
//  TTPlayer for macOS
//
//  增强型音频播放器（集成均衡器和频谱分析）
//

import Foundation
import AVFoundation
import Combine

/// 增强型音频播放器
class EnhancedAudioPlayer: ObservableObject {
    // MARK: - Published Properties

    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var volume: Float = 0.8
    @Published var isMuted = false
    @Published var currentTrack: Track?

    // MARK: - Audio Components

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()

    let equalizer: AudioEqualizer
    let analyzer: SpectrumAnalyzer

    private var audioFile: AVAudioFile?
    private var timeObserverTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        self.equalizer = AudioEqualizer()
        self.analyzer = SpectrumAnalyzer()

        setupAudioEngine()
        setupObservers()
    }

    // MARK: - Setup

    private func setupAudioEngine() {
        // 附加节点
        engine.attach(player)
        engine.attach(equalizer.audioUnit)

        // 连接音频图
        // player → equalizer → mainMixer → output
        let format = AVAudioFormat(
            standardFormatWithSampleRate: 44100,
            channels: 2
        )

        engine.connect(player, to: equalizer.audioUnit, format: format)
        engine.connect(equalizer.audioUnit, to: engine.mainMixerNode, format: format)

        // 安装 tap 用于频谱分析
        engine.mainMixerNode.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: format
        ) { [weak self] buffer, _ in
            DispatchQueue.global(qos: .userInitiated).async {
                self?.analyzer.analyze(buffer: buffer)
            }
        }

        // 启动引擎
        do {
            try engine.start()
        } catch {
            print("无法启动音频引擎: \(error)")
        }
    }

    private func setupObservers() {
        // 监听音量变化
        $volume
            .sink { [weak self] newVolume in
                guard let self = self, !self.isMuted else { return }
                self.engine.mainMixerNode.outputVolume = newVolume
            }
            .store(in: &cancellables)
    }

    // MARK: - Playback Control

    /// 加载曲目
    func load(track: Track) {
        currentTrack = track

        do {
            // 加载音频文件
            audioFile = try AVAudioFile(forReading: track.url)

            // 获取时长
            if let file = audioFile {
                let frameCount = AVAudioFrameCount(file.length)
                let sampleRate = file.processingFormat.sampleRate
                duration = Double(frameCount) / sampleRate
            }

            // 重置播放位置
            currentTime = 0

        } catch {
            print("加载音频文件失败: \(error)")
        }
    }

    /// 播放
    func play() {
        guard let file = audioFile else { return }

        do {
            // 停止当前播放
            player.stop()

            // 调度音频文件
            player.scheduleFile(file, at: nil) { [weak self] in
                DispatchQueue.main.async {
                    self?.handleTrackEnd()
                }
            }

            // 开始播放
            player.play()
            isPlaying = true

            // 启动时间观察器
            startTimeObserver()

        } catch {
            print("播放失败: \(error)")
        }
    }

    /// 暂停
    func pause() {
        player.pause()
        isPlaying = false
        stopTimeObserver()
    }

    /// 停止
    func stop() {
        player.stop()
        isPlaying = false
        currentTime = 0
        stopTimeObserver()
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
        guard let file = audioFile else { return }

        player.stop()

        let sampleRate = file.processingFormat.sampleRate
        let framePosition = AVAudioFramePosition(time * sampleRate)

        // 从新位置开始播放
        player.scheduleSegment(
            file,
            startingFrame: framePosition,
            frameCount: AVAudioFrameCount(file.length - framePosition),
            at: nil
        ) { [weak self] in
            DispatchQueue.main.async {
                self?.handleTrackEnd()
            }
        }

        currentTime = time

        if isPlaying {
            player.play()
        }
    }

    // MARK: - Volume Control

    /// 设置音量（0.0 - 1.0）
    func setVolume(_ newVolume: Float) {
        volume = max(0, min(1, newVolume))
        engine.mainMixerNode.outputVolume = isMuted ? 0 : volume
    }

    /// 静音切换
    func toggleMute() {
        isMuted.toggle()
        engine.mainMixerNode.outputVolume = isMuted ? 0 : volume
    }

    // MARK: - Private Methods

    /// 启动时间观察器
    private func startTimeObserver() {
        stopTimeObserver()

        timeObserverTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let file = self.audioFile else { return }

            if let nodeTime = self.player.lastRenderTime,
               let playerTime = self.player.playerTime(forNodeTime: nodeTime) {
                let sampleRate = file.processingFormat.sampleRate
                self.currentTime = Double(playerTime.sampleTime) / sampleRate
            }
        }
    }

    /// 停止时间观察器
    private func stopTimeObserver() {
        timeObserverTimer?.invalidate()
        timeObserverTimer = nil
    }

    /// 处理曲目播放结束
    private func handleTrackEnd() {
        isPlaying = false
        stopTimeObserver()
        NotificationCenter.default.post(name: .trackDidFinishPlaying, object: nil)
    }

    deinit {
        stopTimeObserver()
        engine.stop()
    }
}
