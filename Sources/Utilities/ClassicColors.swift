//
//  ClassicColors.swift
//  TTPlayer for macOS
//
//  经典千千静听配色方案
//

import SwiftUI

/// 千千静听经典配色
enum TTPlayerClassicColors {
    // MARK: - 背景色

    /// 主背景：钢蓝黑，接近千千静听默认窗体
    static let mainBackground = Color(hex: "#1B242C")

    /// 频谱区：纯黑
    static let spectrumBackground = Color(hex: "#000000")

    /// 标题栏
    static let titleBar = Color(hex: "#3A4C5C")

    /// 次要背景：歌曲信息、进度槽
    static let secondaryBackground = Color(hex: "#24303A")

    /// 控制栏背景
    static let controlBackground = Color(hex: "#31404C")

    /// 列表当前行
    static let listSelection = Color(hex: "#2F6FA8")

    /// 按钮高光 / 暗边
    static let bevelLight = Color.white.opacity(0.22)
    static let bevelDark = Color.black.opacity(0.55)

    // MARK: - 强调色

    /// 强调色：进度与当前行高亮
    static let accent = Color(hex: "#6FD4EE")

    /// 强调色深色版 #3A9FBD
    static let accentDark = Color(hex: "#3A9FBD")

    // MARK: - 频谱颜色

    /// 频谱顶部：亮绿 #00FF00
    static let spectrumTop = Color(hex: "#00FF00")

    /// 频谱中间：中绿 #00AA00
    static let spectrumMid = Color(hex: "#00AA00")

    /// 频谱底部：深绿 #006600
    static let spectrumBottom = Color(hex: "#006600")

    /// 频谱渐变
    static var spectrumGradient: LinearGradient {
        LinearGradient(
            colors: [spectrumTop, spectrumMid, spectrumBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - 文字颜色

    /// 主文字：白色
    static let primaryText = Color.white

    /// 次要文字：60% 透明白色
    static let secondaryText = Color.white.opacity(0.6)

    /// 三级文字：40% 透明白色
    static let tertiaryText = Color.white.opacity(0.4)

    /// 禁用文字：20% 透明白色
    static let disabledText = Color.white.opacity(0.2)

    // MARK: - 进度条

    /// 进度条背景（未播放部分）
    static let progressBackground = mainBackground

    /// 进度条渐变（已播放部分）
    static var progressGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accentDark],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Color Extension

extension Color {
    /// 从十六进制字符串创建颜色
    /// - Parameter hex: 十六进制颜色字符串，如 "#1A1A1A" 或 "1A1A1A"
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (r, g, b) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}
