//
//  AudioEqualizer.swift
//  TTPlayer for macOS
//
//  音频均衡器（10段）
//

import Foundation
import AVFoundation

/// 均衡器频段
struct EqualizerBand: Identifiable {
    let id = UUID()
    let frequency: Float      // 中心频率（Hz）
    var gain: Float           // 增益（dB）-12 ~ +12
    let index: Int

    var displayFrequency: String {
        if frequency < 1000 {
            return "\(Int(frequency)) Hz"
        } else {
            return "\(Int(frequency / 1000)) kHz"
        }
    }
}

/// 均衡器预设
enum EqualizerPreset: String, CaseIterable {
    case off = "关闭"
    case rock = "摇滚"
    case pop = "流行"
    case jazz = "爵士"
    case classical = "古典"
    case dance = "舞曲"
    case metal = "金属"
    case acoustic = "原声"
    case bass = "重低音"
    case treble = "高音增强"

    /// 预设的增益值（10个频段）
    var gains: [Float] {
        switch self {
        case .off:
            return [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        case .rock:
            return [5, 3, -2, -3, -1, 1, 3, 4, 5, 5]
        case .pop:
            return [-1, 2, 4, 4, 2, 0, -1, -1, -1, -1]
        case .jazz:
            return [4, 3, 1, 2, -1, -1, 0, 1, 3, 4]
        case .classical:
            return [5, 4, 3, 2, -1, -1, 0, 2, 3, 4]
        case .dance:
            return [6, 4, 2, 0, 0, -2, -3, -3, 0, 1]
        case .metal:
            return [6, 5, 3, 2, 1, 3, 4, 5, 6, 7]
        case .acoustic:
            return [5, 4, 3, 1, 2, 2, 3, 4, 4, 3]
        case .bass:
            return [8, 7, 6, 4, 2, 0, -2, -3, -4, -5]
        case .treble:
            return [-5, -4, -3, -2, 0, 2, 4, 6, 7, 8]
        }
    }
}

/// 音频均衡器
class AudioEqualizer: ObservableObject {
    // MARK: - Properties

    @Published var isEnabled: Bool = false {
        didSet {
            eq.bypass = !isEnabled
        }
    }

    @Published var bands: [EqualizerBand] = []
    @Published var currentPreset: EqualizerPreset = .off

    private let eq: AVAudioUnitEQ

    // 标准 10 段均衡器频率
    private let frequencies: [Float] = [
        31,     // 超低频
        62,     // 低频
        125,    // 低频
        250,    // 中低频
        500,    // 中频
        1000,   // 中频
        2000,   // 中高频
        4000,   // 高频
        8000,   // 高频
        16000   // 超高频
    ]

    // MARK: - Initialization

    init() {
        self.eq = AVAudioUnitEQ(numberOfBands: 10)
        setupBands()
    }

    /// 获取 AVAudioUnit（用于连接到音频引擎）
    var audioUnit: AVAudioUnit {
        return eq
    }

    // MARK: - Setup

    private func setupBands() {
        for (index, frequency) in frequencies.enumerated() {
            let band = eq.bands[index]
            band.frequency = frequency
            band.bandwidth = 1.0  // 1 octave
            band.bypass = false
            band.filterType = .parametric
            band.gain = 0.0

            bands.append(EqualizerBand(
                frequency: frequency,
                gain: 0,
                index: index
            ))
        }
    }

    // MARK: - Control

    /// 设置单个频段增益
    func setBandGain(index: Int, gain: Float) {
        guard index >= 0 && index < bands.count else { return }

        // 限制范围 ±12 dB
        let clampedGain = max(-12, min(12, gain))

        eq.bands[index].gain = clampedGain
        bands[index].gain = clampedGain

        // 如果手动调整，切换到自定义预设
        if currentPreset != .off {
            currentPreset = .off
        }
    }

    /// 应用预设
    func applyPreset(_ preset: EqualizerPreset) {
        currentPreset = preset
        let gains = preset.gains

        for (index, gain) in gains.enumerated() {
            guard index < bands.count else { break }
            eq.bands[index].gain = gain
            bands[index].gain = gain
        }

        isEnabled = preset != .off
    }

    /// 重置所有频段
    func reset() {
        applyPreset(.off)
    }

    // MARK: - Persistence

    /// 保存设置
    func saveSettings() {
        UserDefaults.standard.set(isEnabled, forKey: "equalizer.enabled")
        UserDefaults.standard.set(currentPreset.rawValue, forKey: "equalizer.preset")

        let gainValues = bands.map { $0.gain }
        UserDefaults.standard.set(gainValues, forKey: "equalizer.gains")
    }

    /// 加载设置
    func loadSettings() {
        isEnabled = UserDefaults.standard.bool(forKey: "equalizer.enabled")

        if let presetName = UserDefaults.standard.string(forKey: "equalizer.preset"),
           let preset = EqualizerPreset(rawValue: presetName) {
            applyPreset(preset)
        } else if let gainValues = UserDefaults.standard.array(forKey: "equalizer.gains") as? [Float],
                  gainValues.count == bands.count {
            for (index, gain) in gainValues.enumerated() {
                setBandGain(index: index, gain: gain)
            }
        }
    }
}
