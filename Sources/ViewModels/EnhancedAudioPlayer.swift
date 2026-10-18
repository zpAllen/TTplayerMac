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
    /// 按曲目里的 ReplayGain 调整响度。默认开。
    @Published var replayGainEnabled = true

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
    /// 切歌淡出完成前如果又切了一次，丢掉前一次。
    private var switchGeneration = 0
    private var fadeGeneration = 0
    private var fadeTimer: Timer?
    private var fadeActive = false
    private var replayGainDB: Float?
    private var replayPeak: Float?

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
            .sink { [weak self] _ in
                self?.applyUserVolume()
            }
            .store(in: &cancellables)
    }

    // MARK: - Playback Control

    /// 加载曲目，不淡出。切歌请用 playTrack。
    func load(track: Track) {
        install(track)
    }

    /// 换歌：正在播时先淡出约 0.3 秒，再播新的一首并淡入。
    func playTrack(_ track: Track) {
        switchGeneration += 1
        let generation = switchGeneration
        let start = { [weak self] in
            guard let self, self.switchGeneration == generation else { return }
            self.install(track)
            self.play()
        }
        if isPlaying {
            fade(towardSilence: true, duration: 0.3, completion: start)
        } else {
            start()
        }
    }

    /// 播放。暂停后继续，而不是从头再来。开始时淡入 0.3 秒。
    func play() {
        guard audioFile != nil else { return }

        if !needsSchedule {
            if !engine.isRunning {
                try? engine.start()
            }
            engine.mainMixerNode.outputVolume = 0
            player.play()
            isPlaying = true
            startTimeObserver()
            beginFadeIn()
            return
        }

        schedule(from: seekOrigin, play: true)
    }

    /// 暂停。淡出 0.5 秒后再停下，避免截断。
    func pause() {
        guard isPlaying else { return }
        switchGeneration += 1
        fade(towardSilence: true, duration: 0.5) { [weak self] in
            guard let self, self.isPlaying else { return }
            self.player.pause()
            self.isPlaying = false
            self.stopTimeObserver()
            self.engine.mainMixerNode.outputVolume = self.isMuted ? 0 : self.volume
        }
    }

    /// 停止。淡出 0.8 秒后回到开头。
    func stop() {
        switchGeneration += 1
        guard isPlaying else {
            halt()
            currentTime = 0
            seekOrigin = 0
            return
        }
        fade(towardSilence: true, duration: 0.8) { [weak self] in
            guard let self else { return }
            self.halt()
            self.currentTime = 0
            self.seekOrigin = 0
        }
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
        schedule(from: clamped, play: wasPlaying, fadeIn: false)
    }

    // MARK: - Volume Control

    /// 设置音量（0.0 - 1.0）
    func setVolume(_ newVolume: Float) {
        volume = max(0, min(1, newVolume))
    }

    /// 静音切换
    func toggleMute() {
        isMuted.toggle()
        applyUserVolume()
    }

    func setReplayGainEnabled(_ enabled: Bool) {
        replayGainEnabled = enabled
        applyReplayGain()
    }

    /// 元数据后到时补上增益，不必重新装载文件。
    func updateReplayGain(db: Float?, peak: Float?) {
        replayGainDB = db
        replayPeak = peak
        applyReplayGain()
    }

    // MARK: - Private Methods

    private func reconnect(format: AVAudioFormat) {
        let wasRunning = engine.isRunning
        engine.stop()
        connectGraph(format: format)
        applyUserVolume()
        if wasRunning || true {
            try? engine.start()
        }
    }

    private func install(_ track: Track) {
        halt()
        currentTrack = track
        currentTime = 0
        seekOrigin = 0
        duration = track.duration
        replayGainDB = track.replayGainDB
        replayPeak = track.replayPeak
        applyReplayGain()

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

    /// 停掉当前调度，不发“播完”通知。
    private func halt() {
        scheduleToken += 1
        fadeGeneration += 1
        fadeTimer?.invalidate()
        fadeTimer = nil
        fadeActive = false
        player.stop()
        isPlaying = false
        needsSchedule = true
        stopTimeObserver()
        analyzer.reset()
        applyUserVolume()
    }

    /// 开始播放时的淡入。
    private func beginFadeIn() {
        engine.mainMixerNode.outputVolume = 0
        fade(towardSilence: false, duration: 0.3, completion: nil)
    }

    /// 用户音量。淡入淡出进行时不打断。
    private func applyUserVolume() {
        guard !fadeActive else { return }
        engine.mainMixerNode.outputVolume = isMuted ? 0 : volume
    }

    /// 峰值限制后的 ReplayGain，加到均衡器总增益上。
    private func applyReplayGain() {
        let gainDB: Float
        if replayGainEnabled, let db = replayGainDB {
            var linear = pow(10, db / 20)
            if let peak = replayPeak, peak > 0.0001 {
                linear = min(linear, 1 / peak)
            }
            gainDB = 20 * log10(max(linear, 0.001))
        } else {
            gainDB = 0
        }
        equalizer.setGlobalGain(db: max(-96, min(24, gainDB)))
    }

    private func fade(towardSilence: Bool, duration: TimeInterval, completion: (() -> Void)?) {
        fadeGeneration += 1
        let generation = fadeGeneration
        fadeTimer?.invalidate()
        fadeActive = true
        let start = engine.mainMixerNode.outputVolume
        let steps = max(1, Int(duration / 0.02))
        var step = 0
        let timer = Timer(timeInterval: duration / Double(steps), repeats: true) { [weak self] timer in
            guard let self, self.fadeGeneration == generation else {
                timer.invalidate()
                return
            }
            step += 1
            let t = min(1, Float(step) / Float(steps))
            let end: Float = towardSilence ? 0 : (self.isMuted ? 0 : self.volume)
            self.engine.mainMixerNode.outputVolume = start + (end - start) * t
            if step >= steps {
                timer.invalidate()
                if self.fadeGeneration == generation {
                    self.fadeTimer = nil
                    self.fadeActive = false
                    completion?()
                }
            }
        }
        fadeTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func schedule(from time: TimeInterval, play shouldPlay: Bool, fadeIn: Bool = true) {
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
            if fadeIn {
                engine.mainMixerNode.outputVolume = 0
            } else {
                applyUserVolume()
            }
            player.play()
            isPlaying = true
            startTimeObserver()
            if fadeIn {
                beginFadeIn()
            }
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
