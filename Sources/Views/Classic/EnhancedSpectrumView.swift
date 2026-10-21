//
//  EnhancedSpectrumView.swift
//  TTPlayer for macOS
//
//  真实 FFT 频谱，黑底绿柱，铺满主窗口宽度
//

import SwiftUI
import AppKit
import Combine

/// 频谱视图。用原生 NSView 直接画柱子，不走 SwiftUI 渲染管线——
/// 频谱每秒更新约 30 次，走 SwiftUI 会让整个窗口跟着布局、提交，
/// 播放时 CPU 会从个位数涨到 20% 以上。
struct EnhancedSpectrumView: NSViewRepresentable {
    var analyzer: SpectrumAnalyzer
    var embedsInSkin = false

    func makeNSView(context: Context) -> SpectrumBarsView {
        let view = SpectrumBarsView()
        view.embedsInSkin = embedsInSkin
        view.bind(analyzer)
        return view
    }

    func updateNSView(_ view: SpectrumBarsView, context: Context) {
        view.embedsInSkin = embedsInSkin
        view.bind(analyzer)
    }
}

/// 直接绘制频谱柱。被皮肤内嵌和自绘界面共用。
final class SpectrumBarsView: NSView {
    var embedsInSkin = false {
        didSet { if embedsInSkin != oldValue { needsDisplay = true } }
    }

    private(set) var values: [Float] = []
    private var palette: SpectrumPalette = .green
    private var analyzer: SpectrumAnalyzer?
    private var cancellable: AnyCancellable?
    private var paletteObserver: NSObjectProtocol?

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { embedsInSkin == false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        refreshPalette()
        paletteObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshPalette()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let paletteObserver {
            NotificationCenter.default.removeObserver(paletteObserver)
        }
    }

    /// 订阅频谱数据。主线程发布，直接改值后重绘。
    func bind(_ analyzer: SpectrumAnalyzer) {
        guard self.analyzer !== analyzer else { return }
        self.analyzer = analyzer
        cancellable = analyzer.$spectrumData
            .sink { [weak self] values in
                guard let self, self.values != values else { return }
                self.values = values
                self.needsDisplay = true
            }
    }

    private func refreshPalette() {
        let name = UserDefaults.standard.string(forKey: "spectrum.palette") ?? SpectrumPalette.green.rawValue
        let next = SpectrumPalette(rawValue: name) ?? .green
        guard next != palette else { return }
        palette = next
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        if !embedsInSkin {
            context.setFillColor(TTPlayerClassicColors.spectrumBackgroundNS.cgColor)
            context.fill(bounds)
        }

        guard !values.isEmpty else { return }

        let inset: CGFloat = embedsInSkin ? 1 : 6
        let bottom: CGFloat = embedsInSkin ? 1 : 4
        let usableWidth = bounds.width - inset * 2
        let usableHeight = bounds.height - bottom
        guard usableWidth > 1, usableHeight > 1 else { return }

        let slot = usableWidth / CGFloat(values.count)
        let barWidth = max(1, slot - 1)
        let colors = palette.nsColors.map(\.cgColor) as CFArray
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
            colors: colors,
            locations: [0, 0.5, 1]
        ) else { return }

        for (index, value) in values.enumerated() {
            guard value > 0.02 else { continue }
            let height = max(1, CGFloat(value) * (usableHeight - 2))
            let rect = CGRect(
                x: inset + CGFloat(index) * slot,
                y: usableHeight - height,
                width: barWidth,
                height: height
            )
            context.saveGState()
            context.addPath(CGPath(roundedRect: rect, cornerWidth: 0.5, cornerHeight: 0.5, transform: nil))
            context.clip()
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: rect.midX, y: rect.minY),
                end: CGPoint(x: rect.midX, y: rect.maxY),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
            context.restoreGState()
        }
    }
}

extension TTPlayerClassicColors {
    /// 原生绘制用的频谱底色（纯黑）。
    static var spectrumBackgroundNS: NSColor {
        NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
    }
}
