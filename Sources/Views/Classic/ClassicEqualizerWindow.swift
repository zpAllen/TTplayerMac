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
    var embedded = false
    var onPopOut: (() -> Void)? = nil

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
                    .accessibilityLabel("启用均衡器")

                if embedded {
                    PopOutButton(help: "在单独窗口打开均衡器", action: { onPopOut?() })
                }
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
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(equalizer.bands) { band in
                    EqualizerBandView(
                        band: band,
                        onGainChange: { newGain in
                            equalizer.setBandGain(index: band.index, gain: newGain)
                        }
                    )
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(TTPlayerClassicColors.mainBackground)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TTPlayerClassicColors.mainBackground)
    }
}

/// 单个频段控制器
struct EqualizerBandView: View {
    let band: EqualizerBand
    let onGainChange: (Float) -> Void

    private var shortFrequency: String {
        if band.frequency < 1000 {
            return "\(Int(band.frequency))"
        }
        return "\(Int(band.frequency / 1000))k"
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(String(format: "%+.0f", band.gain))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(TTPlayerClassicColors.secondaryText)
                .frame(height: 12)

            VerticalGainSlider(
                value: Binding(
                    get: { band.gain },
                    set: { onGainChange($0) }
                )
            )
            .frame(maxHeight: .infinity)
            .frame(minHeight: 80)

            Text(shortFrequency)
                .font(.system(size: 8))
                .foregroundColor(TTPlayerClassicColors.tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(height: 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 竖直增益滑条，0 dB 在中线。直接读写模型，切预设时数字和滑块一起变。
struct VerticalGainSlider: View {
    @Binding var value: Float

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let knobY = yPosition(for: value, height: height)

            ZStack {
                Rectangle()
                    .fill(TTPlayerClassicColors.accent.opacity(0.35))
                    .frame(height: 1)
                    .position(x: geometry.size.width / 2, y: height / 2)

                Capsule()
                    .fill(Color.black.opacity(0.65))
                    .frame(width: 4, height: height)

                Circle()
                    .fill(TTPlayerClassicColors.primaryText)
                    .overlay(Circle().stroke(TTPlayerClassicColors.accent, lineWidth: 1))
                    .frame(width: 10, height: 10)
                    .position(x: geometry.size.width / 2, y: knobY)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let ratio = 1 - min(1, max(0, gesture.location.y / max(height, 1)))
                        value = Float(ratio) * 24 - 12
                    }
            )
        }
    }

    private func yPosition(for gain: Float, height: CGFloat) -> CGFloat {
        let clamped = min(12, max(-12, gain))
        let ratio = CGFloat((clamped + 12) / 24)
        return height * (1 - ratio)
    }
}

// MARK: - Preview

struct ClassicEqualizerWindow_Previews: PreviewProvider {
    static var previews: some View {
        ClassicEqualizerWindow(equalizer: AudioEqualizer())
            .preferredColorScheme(.dark)
    }
}
