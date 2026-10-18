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
class SpectrumAnalyzer: ObservableObject {
    // MARK: - Properties

    @Published var spectrumData: [Float] = Array(repeating: 0, count: 32)

    private let fftSetup: vDSP.FFT<DSPSplitComplex>?
    private let log2n: vDSP_Length
    private let bufferSize: Int = 1024
    private let binCount: Int = 32

    // FFT 缓冲区
    private var realPart: [Float]
    private var imagPart: [Float]
    private var window: [Float]

    // 平滑处理
    private let smoothingFactor: Float = 0.7
    private var previousData: [Float]
    private var sampleRate: Float = 44100

    // MARK: - Initialization

    init() {
        self.log2n = vDSP_Length(log2(Float(bufferSize)))
        self.fftSetup = vDSP.FFT(log2n: log2n, radix: .radix2, ofType: DSPSplitComplex.self)

        self.realPart = [Float](repeating: 0, count: bufferSize / 2)
        self.imagPart = [Float](repeating: 0, count: bufferSize / 2)
        self.previousData = Array(repeating: 0, count: binCount)

        // 创建汉明窗
        self.window = [Float](repeating: 0, count: bufferSize)
        vDSP_hamm_window(&window, vDSP_Length(bufferSize), Int32(vDSP_HANN_NORM))
    }

    // MARK: - Analysis

    /// 清空柱状图。停止播放时调用，避免静音噪声撑满频谱。
    func reset() {
        previousData = Array(repeating: 0, count: binCount)
        spectrumData = previousData
    }

    /// 分析音频缓冲区。FFT 在音频线程算，结果回到主线程再发布。
    func analyze(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        var rms: Float = 0
        vDSP_rmsqv(channelData[0], 1, &rms, vDSP_Length(min(bufferSize, Int(buffer.frameLength))))
        if rms < 0.0008 {
            DispatchQueue.main.async { [weak self] in
                self?.reset()
            }
            return
        }

        let frameLength = Int(buffer.frameLength)
        guard frameLength >= bufferSize else { return }

        sampleRate = Float(buffer.format.sampleRate)

        // 应用汉明窗
        var windowed = [Float](repeating: 0, count: bufferSize)
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
        var magnitudes = [Float](repeating: 0, count: bufferSize / 2)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(bufferSize / 2))

        // 转换为 dB
        var decibels = [Float](repeating: 0, count: bufferSize / 2)
        var reference: Float = 1.0
        vDSP_vdbcon(magnitudes, 1, &reference, &decibels, 1, vDSP_Length(bufferSize / 2), 1)

        // 分组到频段（对数分布）
        updateSpectrumBins(from: decibels)
    }

    /// 更新频谱数据（分组到 32 个柱状图）
    private func updateSpectrumBins(from fftData: [Float]) {
        let frequencyBands = calculateFrequencyBands()
        var newData = [Float](repeating: 0, count: binCount)

        for (index, range) in frequencyBands.enumerated() {
            let startBin = Int(range.lowerBound)
            let endBin = Int(range.upperBound)

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
            let normalized = max(0, min(1, (average + 60) / 60))

            newData[index] = normalized
        }

        let snapshot = newData
        DispatchQueue.main.async { [weak self] in
            self?.publish(snapshot)
        }
    }

    /// 惯性平滑后发布。只在主线程写 @Published。
    private func publish(_ newData: [Float]) {
        var smoothed = newData
        for i in 0..<binCount {
            smoothed[i] = previousData[i] * smoothingFactor + newData[i] * (1 - smoothingFactor)
        }
        previousData = smoothed
        spectrumData = smoothed
    }

    /// 计算对数分布的频率范围
    private func calculateFrequencyBands() -> [ClosedRange<Float>] {
        var bands: [ClosedRange<Float>] = []
        let minFreq: Float = 20.0  // 20 Hz
        let maxFreq: Float = 20000.0  // 20 kHz

        let logMin = log10(minFreq)
        let logMax = log10(maxFreq)
        let logStep = (logMax - logMin) / Float(binCount)

        for i in 0..<binCount {
            let logLower = logMin + Float(i) * logStep
            let logUpper = logMin + Float(i + 1) * logStep

            let lowerFreq = pow(10, logLower)
            let upperFreq = pow(10, logUpper)

            // 转换为 FFT bin 索引
            let lowerBin = frequencyToBin(lowerFreq)
            let upperBin = frequencyToBin(upperFreq)

            bands.append(lowerBin...upperBin)
        }

        return bands
    }

    /// 频率转 FFT bin 索引
    private func frequencyToBin(_ frequency: Float) -> Float {
        let rate = sampleRate > 0 ? sampleRate : 44100
        return frequency * Float(bufferSize) / rate
    }
}
