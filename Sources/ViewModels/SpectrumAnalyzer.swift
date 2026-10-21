//
//  SpectrumAnalyzer.swift
//  TTPlayer for macOS
//
//  音频频谱分析器（FFT）
//

import Foundation
import AVFoundation
import Accelerate

/// 频谱分析器
///
/// 音频线程每次回调都会计算，但主线程最多 30Hz 发布一次：柱状图看不出差别，
/// 主线程重绘量少三成。缓冲区全部复用，回调里不再分配数组。
class SpectrumAnalyzer: ObservableObject {
    // MARK: - Properties

    @Published var spectrumData: [Float] = Array(repeating: 0, count: 32)

    private let fftSetup: vDSP.FFT<DSPSplitComplex>?
    private let log2n: vDSP_Length
    private let bufferSize: Int = 1024
    private let binCount: Int = 32
    /// 主线程发布间隔。约 30Hz，和 tap 的 43Hz 相比几乎看不出区别。
    private let publishInterval: TimeInterval = 1.0 / 30.0

    // FFT 缓冲区（复用，避免每个音频回调分配）
    private var realPart: [Float]
    private var imagPart: [Float]
    private var window: [Float]
    private var windowed: [Float]
    private var magnitudes: [Float]
    private var decibels: [Float]
    private var newData: [Float]

    // 频段边界只在采样率变化时重算
    private var bands: [(start: Int, end: Int)] = []
    private var bandsSampleRate: Float = 0

    // 平滑处理
    private let smoothingFactor: Float = 0.7
    private var previousData: [Float]
    private var sampleRate: Float = 44100

    private var lastPublishTime: TimeInterval = 0
    private var isSilent = true

    // MARK: - Initialization

    init() {
        self.log2n = vDSP_Length(log2(Float(bufferSize)))
        self.fftSetup = vDSP.FFT(log2n: log2n, radix: .radix2, ofType: DSPSplitComplex.self)

        self.realPart = [Float](repeating: 0, count: bufferSize / 2)
        self.imagPart = [Float](repeating: 0, count: bufferSize / 2)
        self.previousData = Array(repeating: 0, count: binCount)
        self.windowed = [Float](repeating: 0, count: bufferSize)
        self.magnitudes = [Float](repeating: 0, count: bufferSize / 2)
        self.decibels = [Float](repeating: 0, count: bufferSize / 2)
        self.newData = Array(repeating: 0, count: binCount)

        // 创建汉明窗
        self.window = [Float](repeating: 0, count: bufferSize)
        vDSP_hamm_window(&window, vDSP_Length(bufferSize), Int32(vDSP_HANN_NORM))
    }

    // MARK: - Analysis

    /// 清空柱状图。停止播放时调用，避免静音噪声撑满频谱。
    func reset() {
        previousData = Array(repeating: 0, count: binCount)
        spectrumData = previousData
        isSilent = true
    }

    /// 分析音频缓冲区。FFT 在音频线程算，结果回到主线程再发布。
    func analyze(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        var rms: Float = 0
        vDSP_rmsqv(channelData[0], 1, &rms, vDSP_Length(min(bufferSize, Int(buffer.frameLength))))
        if rms < 0.0008 {
            publishSilence()
            return
        }

        let frameLength = Int(buffer.frameLength)
        guard frameLength >= bufferSize else { return }

        isSilent = false
        sampleRate = Float(buffer.format.sampleRate)

        // 应用汉明窗
        vDSP_vmul(
            channelData[0], 1,
            window, 1,
            &windowed, 1,
            vDSP_Length(bufferSize)
        )

        // 分离实部和虚部
        var splitComplex = DSPSplitComplex(
            realp: &realPart,
            imagp: &imagPart
        )

        // 转换为复数格式
        windowed.withUnsafeBytes { ptr in
            ptr.bindMemory(to: DSPComplex.self).baseAddress.map {
                vDSP_ctoz($0, 2, &splitComplex, 1, vDSP_Length(bufferSize / 2))
            }
        }

        // 执行 FFT
        fftSetup?.forward(input: splitComplex, output: &splitComplex)

        // 计算幅度
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(bufferSize / 2))

        // 转换为 dB
        var reference: Float = 1.0
        vDSP_vdbcon(magnitudes, 1, &reference, &decibels, 1, vDSP_Length(bufferSize / 2), 1)

        // 分组到频段（对数分布）
        updateSpectrumBins(from: decibels)
    }

    /// 静音只发布一次。之前每个回调都赋全零数组，@Published 会 43Hz 触发重绘。
    private func publishSilence() {
        guard !isSilent else { return }
        DispatchQueue.main.async { [weak self] in
            self?.reset()
        }
    }

    /// 更新频谱数据（分组到 32 个柱状图）
    private func updateSpectrumBins(from fftData: [Float]) {
        let frequencyBands = frequencyBands()

        for (index, range) in frequencyBands.enumerated() {
            let startBin = range.start
            let endBin = range.end

            // 计算该频段的平均幅度
            var sum: Float = 0
            var count = 0

            for bin in startBin..<endBin {
                guard bin < fftData.count else { break }
                sum += fftData[bin]
                count += 1
            }

            let average = count > 0 ? sum / Float(count) : 0

            // 归一化到 0-1 范围（-60 dB ~ 0 dB）
            newData[index] = max(0, min(1, (average + 60) / 60))
        }

        // 平滑在音频线程做完，主线程只负责发布
        var changed = false
        for i in 0..<binCount {
            let smoothed = previousData[i] * smoothingFactor + newData[i] * (1 - smoothingFactor)
            if abs(smoothed - previousData[i]) > 0.002 { changed = true }
            previousData[i] = smoothed
        }
        guard changed else { return }

        let now = Date.timeIntervalSinceReferenceDate
        guard now - lastPublishTime >= publishInterval else { return }
        lastPublishTime = now

        let snapshot = previousData
        DispatchQueue.main.async { [weak self] in
            self?.spectrumData = snapshot
        }
    }

    /// 频率边界换算成 FFT bin。采样率不变时直接复用。
    private func frequencyBands() -> [(start: Int, end: Int)] {
        let rate = sampleRate > 0 ? sampleRate : 44100
        guard bands.isEmpty || abs(rate - bandsSampleRate) > 0.5 else { return bands }

        let minFreq: Float = 20.0  // 20 Hz
        let maxFreq: Float = 20000.0  // 20 kHz

        let logMin = log10(minFreq)
        let logMax = log10(maxFreq)
        let logStep = (logMax - logMin) / Float(binCount)

        bands = (0..<binCount).map { index in
            let lowerFreq = pow(10, logMin + Float(index) * logStep)
            let upperFreq = pow(10, logMin + Float(index + 1) * logStep)
            let lowerBin = Int(frequencyToBin(lowerFreq, rate: rate))
            let upperBin = Int(frequencyToBin(upperFreq, rate: rate))
            return (start: max(0, lowerBin), end: max(lowerBin + 1, upperBin))
        }
        bandsSampleRate = rate
        return bands
    }

    /// 频率转 FFT bin 索引
    private func frequencyToBin(_ frequency: Float, rate: Float) -> Float {
        frequency * Float(bufferSize) / rate
    }
}
