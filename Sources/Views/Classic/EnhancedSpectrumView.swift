//
//  EnhancedSpectrumView.swift
//  TTPlayer for macOS
//
//  真实 FFT 频谱，黑底绿柱，铺满主窗口宽度
//

import SwiftUI

struct EnhancedSpectrumView: View {
    @ObservedObject var analyzer: SpectrumAnalyzer
    var embedsInSkin = false
    @AppStorage("spectrum.palette") private var paletteName = SpectrumPalette.green.rawValue

    private var gradient: LinearGradient {
        (SpectrumPalette(rawValue: paletteName) ?? .green).gradient
    }

    var body: some View {
        GeometryReader { geometry in
            let values = analyzer.spectrumData
            HStack(alignment: .bottom, spacing: 1) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                    RoundedRectangle(cornerRadius: 0.5)
                        .fill(gradient)
                        .frame(height: barHeight(value, in: geometry.size.height))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
            }
            .padding(.horizontal, embedsInSkin ? 1 : 6)
            .padding(.bottom, embedsInSkin ? 1 : 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .background(embedsInSkin ? Color.clear : TTPlayerClassicColors.spectrumBackground)
    }

    private func barHeight(_ value: Float, in height: CGFloat) -> CGFloat {
        guard value > 0.02 else { return 0 }
        let inset: CGFloat = embedsInSkin ? 2 : 6
        return max(1, CGFloat(value) * (height - inset))
    }
}
