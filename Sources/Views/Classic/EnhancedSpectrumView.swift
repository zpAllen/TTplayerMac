//
//  EnhancedSpectrumView.swift
//  TTPlayer for macOS
//
//  增强型频谱视图（使用真实 FFT 数据）
//

import SwiftUI

/// 增强型频谱可视化视图
struct EnhancedSpectrumView: View {
    @ObservedObject var analyzer: SpectrumAnalyzer

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(Array(analyzer.spectrumData.enumerated()), id: \.offset) { index, value in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(TTPlayerClassicColors.spectrumGradient)
                        .frame(
                            width: (geometry.size.width - 62) / 32,
                            height: CGFloat(value) * geometry.size.height
                        )
                        .animation(.easeOut(duration: 0.05), value: value)
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.horizontal, 4)
        }
        .background(TTPlayerClassicColors.mainBackground)
    }
}

// MARK: - Preview

struct EnhancedSpectrumView_Previews: PreviewProvider {
    static var previews: some View {
        EnhancedSpectrumView(analyzer: SpectrumAnalyzer())
            .frame(width: 327, height: 60)
            .preferredColorScheme(.dark)
    }
}
