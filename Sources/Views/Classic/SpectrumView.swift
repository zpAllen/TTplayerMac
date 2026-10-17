//
//  SpectrumView.swift
//  TTPlayer for macOS
//
//  经典频谱可视化组件
//

import SwiftUI
import AVFoundation

/// 频谱可视化视图（经典千千静听绿色频谱）
struct SpectrumView: View {
    @State private var bars: [CGFloat] = Array(repeating: 0.1, count: 32)

    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(0..<32, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(TTPlayerClassicColors.spectrumGradient)
                        .frame(
                            width: (geometry.size.width - 62) / 32,  // 32个柱子，31个间隙
                            height: bars[index] * geometry.size.height
                        )
                        .animation(.easeOut(duration: 0.1), value: bars[index])
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.horizontal, 4)
        }
        .background(TTPlayerClassicColors.mainBackground)
        .onReceive(timer) { _ in
            updateBars()
        }
    }

    /// 更新频谱柱状图
    private func updateBars() {
        // TODO: 接入真实的音频频谱数据
        // 目前使用随机数据模拟
        bars = bars.map { _ in CGFloat.random(in: 0.2...0.95) }
    }
}

// MARK: - Preview

struct SpectrumView_Previews: PreviewProvider {
    static var previews: some View {
        SpectrumView()
            .frame(width: 327, height: 60)
            .preferredColorScheme(.dark)
    }
}
