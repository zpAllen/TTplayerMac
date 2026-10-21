//
//  SkinPlayerView.swift
//  TTPlayer for macOS
//
//  按皮肤坐标画主窗口，并把点击交回播放器。
//

import SwiftUI
import AppKit
import Combine
import Accelerate

struct SkinSnapshot: Equatable {
    var isPlaying: Bool
    var isMuted: Bool
    var time: TimeInterval
    var duration: TimeInterval
    var volume: Float
    var title: String
    var status: String
    var playlistOn: Bool
    var lyricsOn: Bool
    var equalizerOn: Bool
    var desktopLyricOn: Bool
    var canPrev: Bool
    var canNext: Bool
}

struct SkinPlayerView: NSViewRepresentable {
    var window: LoadedWindow
    var snapshot: SkinSnapshot
    /// 画布自己订阅播放器拿时间和时长，SwiftUI 不参与每秒十次的刷新。
    var player: EnhancedAudioPlayer?
    var analyzer: SpectrumAnalyzer
    var onButton: (String) -> Void
    var onSeek: (TimeInterval) -> Void
    var onVolume: (Float) -> Void

    func makeNSView(context: Context) -> SkinCanvas {
        let canvas = SkinCanvas()
        canvas.analyzer = analyzer
        canvas.onButton = onButton
        canvas.onSeek = onSeek
        canvas.onVolume = onVolume
        canvas.bindPlayer(player)
        canvas.apply(window: window, snapshot: snapshot)
        return canvas
    }

    func updateNSView(_ canvas: SkinCanvas, context: Context) {
        canvas.onButton = onButton
        canvas.onSeek = onSeek
        canvas.onVolume = onVolume
        canvas.analyzer = analyzer
        canvas.bindPlayer(player)
        canvas.apply(window: window, snapshot: snapshot)
    }
}

final class SkinCanvas: NSView {
    var onButton: ((String) -> Void)?
    var onSeek: ((TimeInterval) -> Void)?
    var onVolume: ((Float) -> Void)?
    var analyzer: SpectrumAnalyzer?

    private var skin = LoadedWindow(image: NSImage(), size: .zero, controls: [])
    private var snapshot = SkinSnapshot(
        isPlaying: false, isMuted: false, time: 0, duration: 0, volume: 0.8,
        title: "", status: "", playlistOn: false, lyricsOn: false, equalizerOn: false,
        desktopLyricOn: false, canPrev: false, canNext: false
    )
    private var hover: String?
    private var pressed: String?
    private var drag: DragKind?
    private var spectrumHost: SpectrumBarsView?
    private var tracking: NSTrackingArea?
    private var boundPlayer: EnhancedAudioPlayer?
    private var playerCancellable: AnyCancellable?
    /// 皮肤图按目标像素尺寸缓存，避免每帧重新采样。
    private var sharpCache: [SharpBitmap.Key: CGImage] = [:]
    /// 按钮覆盖文字的底色按切片缓存，避免每帧重建位图取样。
    private var fillCache: [ButtonFillKey: NSColor] = [:]

    private struct ButtonFillKey: Hashable {
        let image: ObjectIdentifier
        let sx: Int
        let sy: Int
        let sw: Int
        let sh: Int
    }

    private enum DragKind {
        case progress
        case volume
    }

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(window: LoadedWindow, snapshot: SkinSnapshot) {
        // SwiftUI 递进来的快照不带时间；时间和时长以播放器当前值为准，
        // 避免一次普通重算把进度条打回 0。
        var next = snapshot
        if let player = boundPlayer {
            next.time = player.currentTime
            next.duration = player.duration
        }
        let imageChanged = skin.image !== window.image
        let skinChanged = imageChanged || skin.size != window.size || skin.controls.count != window.controls.count
        let snapshotChanged = self.snapshot != next
        if imageChanged {
            sharpCache.removeAll()
            fillCache.removeAll()
        }
        skin = window
        self.snapshot = next
        if skinChanged {
            installSpectrum()
        }
        // 父视图会因为歌词、列表等无关状态重算，快照没变就别整窗重绘。
        guard skinChanged || snapshotChanged else { return }
        needsDisplay = true
    }

    /// 订阅播放器的时间刷新。每秒十次的重绘只停在这块画布上。
    func bindPlayer(_ player: EnhancedAudioPlayer?) {
        guard boundPlayer !== player else { return }
        boundPlayer = player
        playerCancellable = nil
        guard let player else { return }
        playerCancellable = player.$currentTime
            .merge(with: player.$duration)
            .sink { [weak self] _ in
                guard let self, let player = self.boundPlayer else { return }
                var next = self.snapshot
                next.time = player.currentTime
                next.duration = player.duration
                let previous = self.snapshot
                guard next != previous else { return }
                self.snapshot = next
                // LED 只显示到秒，进度条每秒移动不到一个像素。时间刷新十次里
                // 大多数根本看不出变化，没必要整窗重绘。
                guard self.showsDifferentPixels(previous: previous, next: next) else { return }
                self.needsDisplay = true
            }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        layer?.contentsScale = backingScale
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        layer?.contentsScale = backingScale
        sharpCache.removeAll()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        drawSkin()
    }

    override func layout() {
        super.layout()
        guard let host = spectrumHost, let visual = skin.controls.compactMap({ control -> CGRect? in
            if case let .visual(rect) = control { return rect }
            return nil
        }).first else { return }
        let frame = place(visual)
        guard host.frame != frame else { return }
        // 布局过程中改子视图大小会回头要求窗口更新约束。
        DispatchQueue.main.async { [weak host] in
            guard let host, host.frame != frame else { return }
            host.frame = frame
        }
    }

    /// 窗口拉宽时，整张皮肤按宽度同比放大，点击区域跟着变。
    private var displayScale: CGFloat {
        guard skin.size.width > 1, bounds.width > 1 else { return 1 }
        return bounds.width / skin.size.width
    }

    private func place(_ rect: CGRect) -> CGRect {
        let scale = displayScale
        return CGRect(x: rect.minX * scale, y: rect.minY * scale, width: rect.width * scale, height: rect.height * scale)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking {
            removeTrackingArea(tracking)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        tracking = area
    }

    private func drawSkin() {
        // 整窗背景分数倍放大时允许轻微锐化（透明圆角在锐化后回填原 alpha），
        // 窗口拉成非整数倍也不糊。
        drawBitmap(skin.image, from: NSRect(origin: .zero, size: skin.image.size), in: CGRect(origin: .zero, size: skin.size), sharpenIfFractional: true)
        for control in skin.controls {
            switch control {
            case let .progress(rect, thumb, fill, groove):
                drawProgress(rect: rect, thumb: thumb, fill: fill, groove: groove)
            case let .volume(rect, fill, vertical):
                drawVolume(rect: rect, fill: fill, vertical: vertical)
            case let .button(id, rect, image, states):
                guard isVisible(id) else { continue }
                drawSlice(image, states: states, state: state(for: id, count: states), id: id, in: rect)
            case let .label(id, rect, color, fontSize, align):
                drawLabel(text(for: id), rect: rect, color: color, fontSize: fontSize, align: align)
            case let .led(rect, digits):
                drawLED(digits, in: rect)
            case .visual:
                break
            }
        }
    }

    private func drawProgress(rect: CGRect, thumb: NSImage?, fill: NSImage?, groove: NSImage?) {
        let ratio = progressRatio
        if let groove {
            drawBar(groove, in: rect, ratio: 1)
        }
        if let fill {
            drawBar(fill, in: rect, ratio: ratio)
        }
        guard let thumb else { return }
        let states = stripCount(thumb)
        let slice = thumb.size.width / CGFloat(states)
        let index = drag == .progress ? min(2, states - 1) : 0
        let source = NSRect(x: slice * CGFloat(index), y: 0, width: slice, height: thumb.size.height)
        let frame = CGRect(
            x: rect.minX + (rect.width - slice) * ratio,
            y: rect.midY - thumb.size.height / 2,
            width: slice,
            height: thumb.size.height
        )
        drawBitmap(thumb, from: source, in: frame)
    }

    /// 进度滑块是 4 个等宽状态横排，高度和单颗滑块一致。
    private func stripCount(_ image: NSImage) -> Int {
        let ratio = image.size.width / max(image.size.height, 1)
        for count in [4, 3, 2] where abs(ratio - CGFloat(count)) < 0.35 {
            return count
        }
        return 1
    }

    private func drawBar(_ image: NSImage, in rect: CGRect, ratio: CGFloat) {
        let height = min(image.size.height, rect.height)
        let bar = CGRect(x: rect.minX, y: rect.midY - height / 2, width: rect.width, height: height)
        let clip = place(CGRect(x: rect.minX, y: rect.minY, width: max(0, rect.width * ratio), height: rect.height))
        guard clip.width > 0, clip.height > 0 else { return }
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: clip).addClip()
        drawBitmap(image, from: NSRect(origin: .zero, size: image.size), in: bar)
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawVolume(rect: CGRect, fill: NSImage?, vertical: Bool) {
        guard let fill else { return }
        let ratio = CGFloat(min(1, max(0, snapshot.volume)))
        let clip: CGRect
        if vertical {
            let filled = rect.height * ratio
            clip = place(CGRect(x: rect.minX, y: rect.maxY - filled, width: rect.width, height: filled))
        } else {
            clip = place(CGRect(x: rect.minX, y: rect.minY, width: rect.width * ratio, height: rect.height))
        }
        guard clip.width > 0, clip.height > 0 else { return }
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: clip).addClip()
        drawBitmap(fill, from: NSRect(origin: .zero, size: fill.size), in: rect)
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawSlice(_ image: NSImage, states: Int, state: Int, id: String, in rect: CGRect) {
        let count = max(1, states)
        let slice = image.size.width / CGFloat(count)
        let source = NSRect(x: slice * CGFloat(min(state, count - 1)), y: 0, width: slice, height: image.size.height)
        drawBitmap(image, from: source, in: rect)
        guard let caption = buttonCaption(id) else { return }
        // 按钮上的字只有十几像素，放大后仍是糊的。盖住原字，改画矢量文字。
        let inner = rect.insetBy(dx: 1.5, dy: 2)
        guard inner.width > 4, inner.height > 4 else { return }
        cachedButtonFillColor(image, source: source).setFill()
        NSBezierPath(rect: place(inner)).fill()
        drawLabel(caption, rect: inner, color: NSColor(srgbRed: 0.94, green: 0.97, blue: 0.98, alpha: 1), fontSize: 10, align: .center)
    }

    /// 按钮底色按切片缓存。时间每秒刷新 10 次，每帧为三个按钮重建位图不划算。
    private func cachedButtonFillColor(_ image: NSImage, source: NSRect) -> NSColor {
        let key = ButtonFillKey(
            image: ObjectIdentifier(image),
            sx: SharpBitmap.quantize(source.minX),
            sy: SharpBitmap.quantize(source.minY),
            sw: SharpBitmap.quantize(source.width),
            sh: SharpBitmap.quantize(source.height)
        )
        if let cached = fillCache[key] { return cached }
        let color = buttonFillColor(image, source: source)
        fillCache[key] = color
        return color
    }

    private func buttonCaption(_ id: String) -> String? {
        switch id {
        case "playlist": return "列表"
        case "equalizer": return "均衡器"
        case "lyric": return "歌词"
        default: return nil
        }
    }

    /// 取按钮边缘的暗色，避开中间的原文字。
    private func buttonFillColor(_ image: NSImage, source: NSRect) -> NSColor {
        let fallback = NSColor(srgbRed: 0.18, green: 0.25, blue: 0.32, alpha: 1)
        let width = max(1, Int(source.width.rounded()))
        let height = max(1, Int(source.height.rounded()))
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: rep) else { return fallback }
        let previous = NSGraphicsContext.current
        NSGraphicsContext.current = context
        context.imageInterpolation = .none
        image.draw(in: NSRect(x: 0, y: 0, width: width, height: height), from: source, operation: .copy, fraction: 1)
        NSGraphicsContext.current = previous
        let samples = [
            (max(1, width / 6), height / 2),
            (min(width - 2, width * 5 / 6), height / 2),
            (width / 2, max(1, height / 5)),
            (width / 2, min(height - 2, height * 4 / 5))
        ]
        var best = fallback
        var bestLuma = CGFloat.greatestFiniteMagnitude
        for (x, y) in samples {
            guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
            let luma = 0.3 * color.redComponent + 0.59 * color.greenComponent + 0.11 * color.blueComponent
            if luma < bestLuma {
                bestLuma = luma
                best = color
            }
        }
        return best
    }

    /// 标题、立体声、状态用系统中文黑体，按窗口缩放后的字号画在像素网格上。
    private func drawLabel(_ text: String, rect: CGRect, color: NSColor, fontSize: CGFloat, align: NSTextAlignment) {
        let box = pixelAligned(place(rect))
        guard box.width > 1, box.height > 1 else { return }

        let style = NSMutableParagraphStyle()
        style.alignment = align
        style.lineBreakMode = .byTruncatingTail

        // 皮肤里的字框很矮。按比例放大后行高容易冒出框外，下半截会被频谱盖住。
        var size = min(max(1, fontSize * displayScale), max(1, box.height * 0.78))
        var font = Self.interfaceFont(size: size)
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: style
        ]
        var attributed = NSAttributedString(string: text, attributes: attributes)
        var textBounds = attributed.boundingRect(
            with: NSSize(width: box.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        if textBounds.height > box.height, textBounds.height > 0 {
            size = max(1, size * box.height / textBounds.height * 0.92)
            font = Self.interfaceFont(size: size)
            attributes[.font] = font
            attributed = NSAttributedString(string: text, attributes: attributes)
            textBounds = attributed.boundingRect(
                with: NSSize(width: box.width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            )
        }

        var drawBox = box
        // 略靠上，给字脚下留空隙，避免贴到频谱上沿。
        let slack = max(0, box.height - textBounds.height)
        drawBox.origin.y = snap(box.origin.y + slack * 0.25)
        drawBox.size.height = max(1, box.maxY - drawBox.origin.y)
        attributed.draw(with: drawBox, options: [.usesLineFragmentOrigin, .usesFontLeading, .truncatesLastVisibleLine])
    }

    private static func interfaceFont(size: CGFloat) -> NSFont {
        let name = size < 16 ? "PingFangSC-Medium" : "PingFangSC-Regular"
        return NSFont(name: name, size: size) ?? NSFont.systemFont(ofSize: size, weight: size < 16 ? .medium : .regular)
    }

    private func drawLED(_ digits: NSImage, in rect: CGRect) {
        let glyphs = Array("0123456789:-")
        let text = formatTime(snapshot.time)
        let width = digits.size.width / CGFloat(glyphs.count)
        let height = digits.size.height
        var x = rect.maxX - width * CGFloat(text.count)
        for character in text {
            guard let index = glyphs.firstIndex(of: character) else { continue }
            let source = NSRect(x: width * CGFloat(index), y: 0, width: width, height: height)
            let dest = CGRect(x: x, y: rect.midY - height / 2, width: width, height: height)
            drawBitmap(digits, from: source, in: dest)
            x += width
        }
    }

    /// 时间刷新后是否真的能看出差别：秒数变了（LED），或进度条至少挪动半个像素。
    private func showsDifferentPixels(previous: SkinSnapshot, next: SkinSnapshot) -> Bool {
        if next.duration != previous.duration { return true }
        if Int(next.time) != Int(previous.time) { return true }
        guard next.duration > 0, let rect = progressRect() else { return true }
        let width = rect.width * displayScale * backingScale
        guard width > 0 else { return true }
        let moved = abs(next.time - previous.time) / next.duration * width
        return moved >= 0.5
    }

    private var progressRatio: CGFloat {
        guard snapshot.duration > 0 else { return 0 }
        return CGFloat(min(1, max(0, snapshot.time / snapshot.duration)))
    }

    private func text(for id: String) -> String {
        switch id {
        case "info": return snapshot.title
        case "status": return snapshot.status
        case "stereo": return "立体声"
        default: return ""
        }
    }

    private func isVisible(_ id: String) -> Bool {
        if id == "play" { return !snapshot.isPlaying }
        if id == "pause" { return snapshot.isPlaying }
        return true
    }

    private func isEnabled(_ id: String) -> Bool {
        switch id {
        case "prev": return snapshot.canPrev
        case "next": return snapshot.canNext
        default: return true
        }
    }

    private func isOn(_ id: String) -> Bool {
        switch id {
        case "playlist": return snapshot.playlistOn
        case "lyric": return snapshot.lyricsOn
        case "equalizer": return snapshot.equalizerOn
        case "browser": return snapshot.desktopLyricOn
        case "mute": return snapshot.isMuted
        default: return false
        }
    }

    private func state(for id: String, count: Int) -> Int {
        if !isEnabled(id) { return min(3, count - 1) }
        if pressed == id { return min(2, count - 1) }
        if hover == id { return min(1, count - 1) }
        if isOn(id) { return min(2, count - 1) }
        return 0
    }

    private func button(at point: CGPoint) -> String? {
        for control in skin.controls.reversed() {
            guard case let .button(id, rect, _, _) = control, rect.contains(point), isVisible(id), isEnabled(id) else { continue }
            return id
        }
        return nil
    }

    private func progressRect() -> CGRect? {
        for control in skin.controls {
            if case let .progress(rect, _, _, _) = control { return rect }
        }
        return nil
    }

    private func volumeRect() -> CGRect? {
        for control in skin.controls {
            if case let .volume(rect, _, _) = control { return rect }
        }
        return nil
    }

    private func skinPoint(_ event: NSEvent) -> CGPoint {
        let point = convert(event.locationInWindow, from: nil)
        let scale = max(displayScale, 0.01)
        return CGPoint(x: point.x / scale, y: point.y / scale)
    }

    override func mouseMoved(with event: NSEvent) {
        let next = button(at: skinPoint(event))
        guard next != hover else { return }
        hover = next
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        hover = nil
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        let point = skinPoint(event)
        if let id = button(at: point) {
            pressed = id
            drag = nil
            needsDisplay = true
            return
        }
        if let rect = progressRect(), rect.insetBy(dx: 0, dy: -4).contains(point) {
            drag = .progress
            seek(at: point, in: rect)
            return
        }
        if let rect = volumeRect(), rect.insetBy(dx: -4, dy: 0).contains(point) {
            drag = .volume
            changeVolume(at: point, in: rect)
            return
        }
        pressed = nil
        drag = nil
        self.window?.performDrag(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        let point = skinPoint(event)
        if drag == .progress, let rect = progressRect() {
            seek(at: point, in: rect)
            return
        }
        if drag == .volume, let rect = volumeRect() {
            changeVolume(at: point, in: rect)
        }
    }

    override func mouseUp(with event: NSEvent) {
        let point = skinPoint(event)
        if let pressed, button(at: point) == pressed {
            onButton?(pressed)
        }
        self.pressed = nil
        drag = nil
        needsDisplay = true
    }

    private func seek(at point: CGPoint, in rect: CGRect) {
        guard snapshot.duration > 0, rect.width > 0 else { return }
        let ratio = min(1, max(0, (point.x - rect.minX) / rect.width))
        onSeek?(snapshot.duration * ratio)
    }

    private func changeVolume(at point: CGPoint, in rect: CGRect) {
        guard rect.height > 0 else { return }
        let ratio = min(1, max(0, (rect.maxY - point.y) / rect.height))
        onVolume?(Float(ratio))
    }

    private var backingScale: CGFloat {
        window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
    }

    private func snap(_ value: CGFloat) -> CGFloat {
        let scale = backingScale
        return (value * scale).rounded() / scale
    }

    private func pixelAligned(_ rect: CGRect) -> CGRect {
        let scale = backingScale
        let minX = (rect.minX * scale).rounded() / scale
        let minY = (rect.minY * scale).rounded() / scale
        let maxX = (rect.maxX * scale).rounded() / scale
        let maxY = (rect.maxY * scale).rounded() / scale
        return CGRect(x: minX, y: minY, width: max(0, maxX - minX), height: max(0, maxY - minY))
    }

    /// 把皮肤位图放大到当前窗口的屏幕像素。接近整数倍时用最近邻，避免按钮字被插值抹平。
    private func drawBitmap(_ image: NSImage, from source: NSRect, in skinRect: CGRect, sharpenIfFractional: Bool = false) {
        let dest = pixelAligned(place(skinRect))
        guard dest.width > 0.5, dest.height > 0.5, source.width > 0.5, source.height > 0.5 else { return }
        let pixelWidth = max(1, Int((dest.width * backingScale).rounded()))
        let pixelHeight = max(1, Int((dest.height * backingScale).rounded()))
        let key = SharpBitmap.Key(
            image: ObjectIdentifier(image),
            sx: SharpBitmap.quantize(source.minX),
            sy: SharpBitmap.quantize(source.minY),
            sw: SharpBitmap.quantize(source.width),
            sh: SharpBitmap.quantize(source.height),
            dw: pixelWidth,
            dh: pixelHeight,
            sharpen: sharpenIfFractional
        )
        let rendered: CGImage
        if let cached = sharpCache[key] {
            rendered = cached
        } else if let made = SharpBitmap.render(image, from: source, width: pixelWidth, height: pixelHeight, sharpenIfFractional: sharpenIfFractional) {
            if sharpCache.count > 96 {
                sharpCache.removeAll()
            }
            sharpCache[key] = made
            rendered = made
        } else {
            image.draw(in: dest, from: source, operation: .sourceOver, fraction: 1)
            return
        }
        guard let context = NSGraphicsContext.current else { return }
        let previous = context.imageInterpolation
        context.imageInterpolation = .none
        NSImage(cgImage: rendered, size: dest.size).draw(
            in: dest,
            from: NSRect(origin: .zero, size: dest.size),
            operation: .sourceOver,
            fraction: 1
        )
        context.imageInterpolation = previous
    }

    private func installSpectrum() {
        spectrumHost?.removeFromSuperview()
        spectrumHost = nil
        guard let analyzer, let visual = skin.controls.compactMap({ control -> CGRect? in
            if case let .visual(rect) = control { return rect }
            return nil
        }).first else { return }

        // 直接放原生绘制视图，不再套一层 NSHostingView/SwiftUI。
        let host = SpectrumBarsView()
        host.embedsInSkin = true
        host.bind(analyzer)
        host.frame = place(visual)
        addSubview(host)
        spectrumHost = host
    }
}

/// 把 1× 皮肤位图放大到屏幕像素。整数倍用最近邻保住按钮边缘，其余用 Lanczos。
private enum SharpBitmap {
    struct Key: Hashable {
        let image: ObjectIdentifier
        let sx: Int
        let sy: Int
        let sw: Int
        let sh: Int
        let dw: Int
        let dh: Int
        let sharpen: Bool
    }

    private static let colorSpace = CGColorSpaceCreateDeviceRGB()

    static func quantize(_ value: CGFloat) -> Int {
        Int((value * 4).rounded())
    }

    static func render(_ image: NSImage, from source: NSRect, width: Int, height: Int, sharpenIfFractional: Bool) -> CGImage? {
        guard let slice = slice(image, from: source) else { return nil }
        return scale(slice, width: max(1, width), height: max(1, height), sharpenIfFractional: sharpenIfFractional)
    }

    private static func slice(_ image: NSImage, from source: NSRect) -> CGImage? {
        let width = max(1, Int(source.width.rounded()))
        let height = max(1, Int(source.height.rounded()))
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
            NSGraphicsContext.restoreGraphicsState()
            return nil
        }
        NSGraphicsContext.current = context
        context.imageInterpolation = .none
        context.shouldAntialias = false
        image.draw(
            in: NSRect(x: 0, y: 0, width: width, height: height),
            from: source,
            operation: .copy,
            fraction: 1,
            respectFlipped: false,
            hints: [.interpolation: NSNumber(value: NSImageInterpolation.none.rawValue)]
        )
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        return rep.cgImage
    }

    private static func scale(_ source: CGImage, width: Int, height: Int, sharpenIfFractional: Bool) -> CGImage? {
        if source.width == width && source.height == height { return source }
        let factor = CGFloat(width) / CGFloat(max(source.width, 1))
        if factor >= 1, abs(factor - factor.rounded()) < 0.02 {
            return resample(source, width: width, height: height, interpolation: .none)
        }
        let stepped = max(1, Int(factor.rounded()))
        let error = abs(factor - CGFloat(stepped)) / CGFloat(stepped)
        if factor >= 1, error <= 0.08 {
            let steppedWidth = source.width * stepped
            let steppedHeight = source.height * stepped
            guard let crisp = resample(source, width: steppedWidth, height: steppedHeight, interpolation: .none) else {
                return nil
            }
            if steppedWidth == width && steppedHeight == height { return crisp }
            return lanczos(crisp, width: width, height: height, sharpen: false)
        }
        // 收紧小图（按钮、数字）和整窗背景。透明边缘在锐化后回填未锐化像素，
        // 圆角镂空处不会出彩色晕；长进度条等控件图仍不锐化。
        let glyph = source.width <= 180 && source.height <= 64
        return lanczos(source, width: width, height: height, sharpen: factor > 1.15 && (glyph || sharpenIfFractional))
    }

    private static func resample(_ image: CGImage, width: Int, height: Int, interpolation: CGInterpolationQuality) -> CGImage? {
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.interpolationQuality = interpolation
        context.setShouldAntialias(interpolation != .none)
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    private static func lanczos(_ image: CGImage, width: Int, height: Int, sharpen: Bool) -> CGImage? {
        var format = vImage_CGImageFormat(
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            colorSpace: Unmanaged.passUnretained(colorSpace),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
            version: 0,
            decode: nil,
            renderingIntent: .defaultIntent
        )
        var source = vImage_Buffer()
        var error = vImageBuffer_InitWithCGImage(&source, &format, nil, image, vImage_Flags(kvImageNoFlags))
        guard error == kvImageNoError else { return resample(image, width: width, height: height, interpolation: .high) }
        defer { free(source.data) }

        var dest = vImage_Buffer()
        error = vImageBuffer_Init(&dest, vImagePixelCount(height), vImagePixelCount(width), 32, vImage_Flags(kvImageNoFlags))
        guard error == kvImageNoError else { return resample(image, width: width, height: height, interpolation: .high) }
        error = vImageScale_ARGB8888(&source, &dest, nil, vImage_Flags(kvImageHighQualityResampling))
        guard error == kvImageNoError else {
            free(dest.data)
            return resample(image, width: width, height: height, interpolation: .high)
        }

        if sharpen {
            var sharpened = vImage_Buffer()
            if vImageBuffer_Init(&sharpened, dest.height, dest.width, 32, vImage_Flags(kvImageNoFlags)) == kvImageNoError {
                // 中心 20、四周 -1、除以 16：只把放大后的笔画边缘收紧一点。
                let kernel: [Int16] = [
                    0, -1, 0,
                    -1, 20, -1,
                    0, -1, 0
                ]
                var background = [UInt8](repeating: 0, count: 4)
                let sharpenError = kernel.withUnsafeBufferPointer { kernelPointer in
                    background.withUnsafeMutableBufferPointer { backgroundPointer in
                        vImageConvolve_ARGB8888(
                            &dest,
                            &sharpened,
                            nil,
                            0,
                            0,
                            kernelPointer.baseAddress!,
                            3,
                            3,
                            16,
                            backgroundPointer.baseAddress!,
                            vImage_Flags(kvImageEdgeExtend)
                        )
                    }
                }
                if sharpenError == kvImageNoError {
                    // 卷积会把不透明像素的亮度混进透明边，圆角镂空处出彩色晕。
                    // 非全不透明的像素整体回退成未锐化的原值，透明边保持干净。
                    mergeBoundaryAlpha(into: &sharpened, from: dest)
                    free(dest.data)
                    dest = sharpened
                } else {
                    free(sharpened.data)
                }
            }
        }

        var createError = vImage_Error(kvImageNoError)
        guard let result = vImageCreateCGImageFromBuffer(&dest, &format, nil, nil, vImage_Flags(kvImageNoFlags), &createError)?.takeRetainedValue(),
              createError == kvImageNoError else {
            free(dest.data)
            return resample(image, width: width, height: height, interpolation: .high)
        }
        free(dest.data)
        return result
    }

    /// alpha != 255 的像素用未锐化缓冲区的原值覆盖，透明边不受卷积污染。
    /// 缓冲区是 premultipliedFirst，每像素 [A, R, G, B]。
    private static func mergeBoundaryAlpha(into sharpened: inout vImage_Buffer, from plain: vImage_Buffer) {
        guard sharpened.width == plain.width, sharpened.height == plain.height,
              let sharpenedData = sharpened.data, let plainData = plain.data else { return }
        let s = sharpenedData.bindMemory(to: UInt8.self, capacity: sharpened.rowBytes * Int(sharpened.height))
        let p = plainData.bindMemory(to: UInt8.self, capacity: plain.rowBytes * Int(plain.height))
        let width = Int(sharpened.width)
        for y in 0..<Int(sharpened.height) {
            let sRow = s + y * sharpened.rowBytes
            let pRow = p + y * plain.rowBytes
            for x in 0..<width {
                let i = x * 4
                guard pRow[i] != 255 else { continue }
                sRow[i] = pRow[i]
                sRow[i + 1] = pRow[i + 1]
                sRow[i + 2] = pRow[i + 2]
                sRow[i + 3] = pRow[i + 3]
            }
        }
    }
}
