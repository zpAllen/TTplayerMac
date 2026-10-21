// TTPlayer 应用图标生成器（千千静听怀旧版）
// 用法：swift Packaging/make_icon.swift
// 产出：Packaging/AppIcon_1024.png（1024×1024 母版）

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let S: CGFloat = 1024

// MARK: - 参数（可调）

// 背景：金 → 橙 渐变（原版 TTPlayer 配色）
let gradTop: UInt32 = 0xF6E3B4  // 顶部奶油金
let gradMid: UInt32 = 0xF2B25C
let gradBot: UInt32 = 0xE2760C  // 底部深橙

// 音符整体旋转角（度）。0 = 标准立式 ♪（头在下、尾在上）
// 原版构图：头居中偏上、符干向右下斜、符尾卷在左下 → 145°
let noteRotation: CGFloat = 145
// 音符组中心在画布上的位置
let noteCenter = CGPoint(x: 512, y: 470)
// 音符缩放
let noteScale: CGFloat = 0.95

// 阴影（原版用深紫褐色投影）
let shadowColor: UInt32 = 0x3A1D55

// MARK: - 工具函数

func color(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: a)
}

// 超椭圆（n=5 近似 macOS 图标圆角）
func superellipse(cx: CGFloat, cy: CGFloat, a: CGFloat, b: CGFloat, n: CGFloat = 5) -> CGPath {
    let path = CGMutablePath()
    let steps = 1440
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
        let c = abs(cos(t)), s = abs(sin(t))
        let x = cx + a * pow(c, 2 / n) * (cos(t) < 0 ? -1 : 1)
        let y = cy + b * pow(s, 2 / n) * (sin(t) < 0 ? -1 : 1)
        if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
    }
    path.closeSubpath()
    return path
}

// 旋转椭圆
func fillEllipse(_ ctx: CGContext, _ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat, _ rot: CGFloat) {
    ctx.saveGState()
    ctx.translateBy(x: cx, y: cy)
    ctx.rotate(by: rot)
    ctx.addEllipse(in: CGRect(x: -rx, y: -ry, width: 2 * rx, height: 2 * ry))
    ctx.fillPath()
    ctx.restoreGState()
}

// 圆角矩形
func fillRoundRect(_ ctx: CGContext, _ rect: CGRect, _ r: CGFloat) {
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil))
    ctx.fillPath()
}

// 线性渐变填充
func fillLinearGradient(_ ctx: CGContext, _ colors: [(UInt32, CGFloat)], _ from: CGPoint, _ to: CGPoint) {
    let cg = colors.map { color($0.0, $0.1) } as CFArray
    let loc: [CGFloat] = colors.map { $0.1 }
    _ = loc
    let positions: [CGFloat] = colors.enumerated().map { i, _ in
        CGFloat(i) / CGFloat(colors.count - 1)
    }
    guard let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cg, locations: positions) else { return }
    ctx.drawLinearGradient(grad, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

// 径向渐变填充
func fillRadialGradient(_ ctx: CGContext, _ colorHex: UInt32, _ center: CGPoint, _ radius: CGFloat, _ fromAlpha: CGFloat) {
    let cols = [color(colorHex, fromAlpha), color(colorHex, 0)] as CFArray
    guard let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cols, locations: [0, 1]) else { return }
    ctx.drawRadialGradient(grad, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
}

// MARK: - 音符造型（立式 ♪，以 (0,0) 为组原点，之后整体旋转）

func drawNote(_ ctx: CGContext) {
    // 符头：左下大椭圆（原版是大头）
    fillEllipse(ctx, -175, 205, 168, 128, -8 * .pi / 180)

    // 符干：右侧竖条（与符头右缘交叠）
    fillRoundRect(ctx, CGRect(x: -14, y: -350, width: 66, height: 555), 28)

    // 符尾：双笔画卷曲（原版样式），从符干向右卷下
    ctx.setLineCap(.round)
    let flag1 = CGMutablePath()
    flag1.move(to: CGPoint(x: 44, y: -345))
    flag1.addCurve(to: CGPoint(x: 270, y: -190),
                   control1: CGPoint(x: 130, y: -400), control2: CGPoint(x: 230, y: -320))
    flag1.addCurve(to: CGPoint(x: 240, y: -35),
                   control1: CGPoint(x: 300, y: -95), control2: CGPoint(x: 275, y: -45))
    ctx.setLineWidth(42)
    ctx.addPath(flag1)
    ctx.strokePath()

    let flag2 = CGMutablePath()
    flag2.move(to: CGPoint(x: 44, y: -205))
    flag2.addCurve(to: CGPoint(x: 200, y: -70),
                   control1: CGPoint(x: 105, y: -235), control2: CGPoint(x: 165, y: -165))
    ctx.setLineWidth(34)
    ctx.addPath(flag2)
    ctx.strokePath()
}

// 四角星闪光
func drawSparkle(_ ctx: CGContext, _ c: CGPoint, _ r: CGFloat) {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: c.x, y: c.y - r))
    p.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + r * 0.22, y: c.y - r * 0.22))
    p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + r * 0.22, y: c.y + r * 0.22))
    p.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - r * 0.22, y: c.y + r * 0.22))
    p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - r * 0.22, y: c.y - r * 0.22))
    p.closeSubpath()
    ctx.addPath(p)
    ctx.fillPath()
}

// MARK: - 绘制

func makeIcon() -> CGImage {
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(
        data: nil, width: Int(S), height: Int(S),
        bitsPerComponent: 8, bytesPerRow: 0, space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    // 翻转为 y 向下，与上面的坐标一致
    ctx.scaleBy(x: 1, y: -1)
    ctx.translateBy(x: 0, y: -S)

    // 1. 圆角底
    let sq = superellipse(cx: S / 2, cy: S / 2, a: 500, b: 500)
    ctx.saveGState()
    ctx.addPath(sq)
    ctx.clip()

    // 2. 金 → 橙渐变
    fillLinearGradient(ctx, [(gradTop, 1), (gradMid, 1), (gradBot, 1)],
                       CGPoint(x: 280, y: 180), CGPoint(x: 744, y: 844))

    // 3. 顶部高光
    fillRadialGradient(ctx, 0xFFFFFF, CGPoint(x: 380, y: 250), 780, 0.30)

    // 4. 底部深色光斑（音符影子落点，原版深紫褐）
    fillRadialGradient(ctx, shadowColor, CGPoint(x: 512, y: 820), 560, 0.42)

    ctx.restoreGState()

    // 5. 内描边
    ctx.saveGState()
    ctx.addPath(superellipse(cx: S / 2, cy: S / 2, a: 478, b: 478))
    ctx.setStrokeColor(color(0xFFFFFF, 0.18))
    ctx.setLineWidth(5)
    ctx.strokePath()
    ctx.restoreGState()

    // 6. 音符（带投影）
    ctx.saveGState()
    ctx.translateBy(x: noteCenter.x, y: noteCenter.y)
    ctx.rotate(by: noteRotation * .pi / 180)
    ctx.scaleBy(x: noteScale, y: noteScale)
    ctx.setShadow(offset: CGSize(width: 24, height: 30), blur: 44, color: color(shadowColor, 0.55))
    ctx.setFillColor(color(0xFFFFFF))
    ctx.setStrokeColor(color(0xFFFFFF))
    drawNote(ctx)
    ctx.restoreGState()

    // 7. 闪光（坐在底部阴影里）
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 18, color: color(0xFFFFFF, 0.5))
    ctx.setFillColor(color(0xFFFFFF, 0.95))
    drawSparkle(ctx, CGPoint(x: 400, y: 845), 44)
    ctx.restoreGState()

    return ctx.makeImage()!
}

// MARK: - 写出 PNG

let img = makeIcon()
let dest = CGImageDestinationCreateWithURL(
    URL(fileURLWithPath: "Packaging/AppIcon_1024.png") as CFURL,
    UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, img, nil)
CGImageDestinationFinalize(dest)
print("✅ Packaging/AppIcon_1024.png")
