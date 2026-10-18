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

    /// 已经装入音频文件，暂停或停止后可以接着播
    var canResume: Bool { audioFile != nil }

    private var audioFile: AVAudioFile?
    private var timeObserverTimer: Timer?
    private var tapInstalled = false
    private var graphConnected = false
    private var cancellables = Set<AnyCancellable>()

    /// 当前调度的起点。AVAudioPlayerNode 的 sampleTime 从片段开头计，要加回这段偏移才是文件时间。
    private var seekOrigin: TimeInterval = 0
    /// 暂停后节点上仍有未播完的调度，再次播放只需 resume，不能整首重排。
    private var needsSchedule = true
    /// stop / seek 会使旧的播完回调迟到，用代号丢掉它们，避免误切下一曲。
    private var scheduleToken = 0

    // MARK: - Initialization

    init() {
        self.equalizer = AudioEqualizer()
        self.analyzer = SpectrumAnalyzer()

        setupAudioEngine()
        setupObservers()
    }

    // MARK: - Setup

    private func setupAudioEngine() {
        engine.attach(player)
        engine.attach(equalizer.audioUnit)

        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)
        connectGraph(format: format)

        do {
            try engine.start()
        } catch {
            print("无法启动音频引擎: \(error)")
        }
    }

    /// 按当前文件的采样率和声道重连，避免 48 kHz 等文件被固定成 44.1 kHz 后播不出来。
    private func connectGraph(format: AVAudioFormat?) {
        if tapInstalled {
            engine.mainMixerNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        if graphConnected {
            engine.disconnectNodeOutput(player)
            engine.disconnectNodeOutput(equalizer.audioUnit)
        }

        engine.connect(player, to: equalizer.audioUnit, format: format)
        engine.connect(equalizer.audioUnit, to: engine.mainMixerNode, format: format)
        graphConnected = true

        engine.mainMixerNode.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: nil
        ) { [weak self] buffer, _ in
            guard let self else { return }
            if self.isPlaying {
                self.analyzer.analyze(buffer: buffer)
            }
        }
        tapInstalled = true
    }

    private func setupObservers() {
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
        halt()
        currentTrack = track
        currentTime = 0
        seekOrigin = 0
        duration = track.duration

        do {
            let file = try AVAudioFile(forReading: track.url)
            audioFile = file
            let sampleRate = file.processingFormat.sampleRate
            if sampleRate > 0 {
                duration = Double(file.length) / sampleRate
            }
            reconnect(format: file.processingFormat)
            needsSchedule = true
        } catch {
            print("加载音频文件失败: \(error)")
            audioFile = nil
            needsSchedule = true
        }
    }

    /// 播放。暂停后继续，而不是从头再来。
    func play() {
        guard audioFile != nil else { return }

        if !needsSchedule {
            if !engine.isRunning {
                try? engine.start()
            }
            player.play()
            isPlaying = true
            startTimeObserver()
            return
        }

        schedule(from: seekOrigin, play: true)
    }

    /// 暂停
    func pause() {
        guard isPlaying else { return }
        player.pause()
        isPlaying = false
        stopTimeObserver()
    }

    /// 停止
    func stop() {
        halt()
        currentTime = 0
        seekOrigin = 0
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
        guard audioFile != nil else { return }
        let upper = duration > 0 ? duration : time
        let clamped = min(max(0, time), upper)
        let wasPlaying = isPlaying
        halt()
        currentTime = clamped
        seekOrigin = clamped
        schedule(from: clamped, play: wasPlaying)
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

    private func reconnect(format: AVAudioFormat) {
        let wasRunning = engine.isRunning
        engine.stop()
        connectGraph(format: format)
        engine.mainMixerNode.outputVolume = isMuted ? 0 : volume
        if wasRunning || true {
            try? engine.start()
        }
    }

    /// 停掉当前调度，不发“播完”通知。
    private func halt() {
        scheduleToken += 1
        player.stop()
        isPlaying = false
        needsSchedule = true
        stopTimeObserver()
        analyzer.reset()
    }

    private func schedule(from time: TimeInterval, play shouldPlay: Bool) {
        guard let file = audioFile else { return }

        let sampleRate = file.processingFormat.sampleRate
        guard sampleRate > 0 else { return }

        let startFrame = AVAudioFramePosition(max(0, time) * sampleRate)
        let remaining = file.length - startFrame
        guard remaining > 0 else {
            handleTrackEnd()
            return
        }

        if !engine.isRunning {
            try? engine.start()
        }

        scheduleToken += 1
        let token = scheduleToken
        seekOrigin = time

        player.scheduleSegment(
            file,
            startingFrame: startFrame,
            frameCount: AVAudioFrameCount(remaining),
            at: nil
        ) { [weak self] in
            DispatchQueue.main.async {
                guard let self, self.scheduleToken == token else { return }
                self.handleTrackEnd()
            }
        }

        needsSchedule = false

        if shouldPlay {
            player.play()
            isPlaying = true
            startTimeObserver()
        }
    }

    /// 启动时间观察器
    private func startTimeObserver() {
        stopTimeObserver()

        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.refreshCurrentTime()
        }
        timeObserverTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func refreshCurrentTime() {
        guard let file = audioFile,
              let nodeTime = player.lastRenderTime,
              let playerTime = player.playerTime(forNodeTime: nodeTime),
              playerTime.sampleTime >= 0 else {
            return
        }

        let sampleRate = file.processingFormat.sampleRate
        guard sampleRate > 0 else { return }

        let rendered = Double(playerTime.sampleTime) / sampleRate
        let absolute = seekOrigin + rendered
        currentTime = duration > 0 ? min(absolute, duration) : absolute
    }

    /// 停止时间观察器
    private func stopTimeObserver() {
        timeObserverTimer?.invalidate()
        timeObserverTimer = nil
    }

    /// 处理曲目播放结束
    private func handleTrackEnd() {
        isPlaying = false
        needsSchedule = true
        seekOrigin = 0
        analyzer.reset()
        if duration > 0 {
            currentTime = duration
        }
        stopTimeObserver()
        NotificationCenter.default.post(name: .trackDidFinishPlaying, object: nil)
    }

    deinit {
        stopTimeObserver()
        engine.stop()
    }
}
