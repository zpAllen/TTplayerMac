//
//  ClassicEqualizerWindow.swift
//  TTPlayer for macOS
//
//  经典均衡器窗口
//

import SwiftUI

/// 经典均衡器窗口
struct ClassicEqualizerWindow: View {
    @ObservedObject var equalizer: AudioEqualizer

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("均衡器")
                    .font(.system(size: 11))
                    .foregroundColor(TTPlayerClassicColors.primaryText)

                Spacer()

                // 开关
                Toggle("", isOn: $equalizer.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .scaleEffect(0.7)

                Button("×") {
                    // 关闭窗口
                }
                .buttonStyle(.plain)
                .foregroundColor(TTPlayerClassicColors.primaryText)
            }
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(TTPlayerClassicColors.controlBackground)

            // 预设选择
            HStack {
                Text("预设:")
                    .font(.system(size: 10))
                    .foregroundColor(TTPlayerClassicColors.secondaryText)

                Picker("", selection: $equalizer.currentPreset) {
                    ForEach(EqualizerPreset.allCases, id: \.self) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: equalizer.currentPreset) { _, newPreset in
                    equalizer.applyPreset(newPreset)
                }

                Spacer()

                Button("重置") {
                    equalizer.reset()
                }
                .buttonStyle(.plain)
                .font(.system(size: 10))
                .foregroundColor(TTPlayerClassicColors.accent)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(TTPlayerClassicColors.secondaryBackground)

            // 频段控制
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(equalizer.bands) { band in
                    EqualizerBandView(
                        band: band,
                        onGainChange: { newGain in
                            equalizer.setBandGain(index: band.index, gain: newGain)
                        }
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            .background(TTPlayerClassicColors.mainBackground)
        }
        .frame(width: 450, height: 200)
    }
}

/// 单个频段控制器
struct EqualizerBandView: View {
    let band: EqualizerBand
    let onGainChange: (Float) -> Void

    @State private var gain: Float

    init(band: EqualizerBand, onGainChange: @escaping (Float) -> Void) {
        self.band = band
        self.onGainChange = onGainChange
        self._gain = State(initialValue: band.gain)
    }

    var body: some View {
        VStack(spacing: 4) {
            // 增益显示
            Text(String(format: "%+.0f", gain))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(TTPlayerClassicColors.secondaryText)
                .frame(height: 14)

            // 滑块
            Slider(
                value: Binding(
                    get: { gain },
                    set: { newValue in
                        gain = newValue
                        onGainChange(newValue)
                    }
                ),
                in: -12...12
            )
            .rotationEffect(.degrees(-90))
            .frame(width: 100, height: 20)
            .tint(TTPlayerClassicColors.accent)

            // 频率标签
            Text(band.displayFrequency)
                .font(.system(size: 9))
                .foregroundColor(TTPlayerClassicColors.tertiaryText)
                .frame(height: 14)
        }
        .frame(width: 32)
    }
}

// MARK: - Preview

struct ClassicEqualizerWindow_Previews: PreviewProvider {
    static var previews: some View {
        ClassicEqualizerWindow(equalizer: AudioEqualizer())
            .preferredColorScheme(.dark)
    }
}
