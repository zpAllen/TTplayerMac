//
//  DesktopLyricWindow.swift
//  TTPlayer for macOS
//
//  桌面歌词：屏幕底部的描边文字，没有歌词时也保持同样大小
//

import SwiftUI
import AppKit

/// 桌面歌词窗口（浮动、置顶、透明）
class DesktopLyricWindow: NSPanel {
    init(contentSize: NSSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        hidesOnDeactivate = false
    }

    /// 设置是否可拖动
    func setDraggable(_ draggable: Bool) {
        isMovableByWindowBackground = draggable
        ignoresMouseEvents = !draggable
    }
}

/// 桌面歌词条。尺寸固定，避免空歌词把窗口收成一个小弹框。
struct DesktopLyricBar: View {
    @ObservedObject var model: DesktopLyricManager

    private var hasLyric: Bool {
        !model.currentLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 8) {
            KaraokeLine(
                text: hasLyric ? model.currentLine : "暂无歌词",
                progress: hasLyric && model.useKaraokeEffect ? model.progress : 0,
                fontSize: 34,
                base: hasLyric ? .white : .white.opacity(0.7),
                played: Color(red: 0.55, green: 1, blue: 0.35)
            )

            if hasLyric, !model.nextLine.isEmpty {
                outlined(model.nextLine, size: 20, color: .white.opacity(0.5))
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func outlined(_ text: String, size: CGFloat, color: Color) -> some View {
        Text(text)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .shadow(color: .black, radius: 0, x: 1, y: 0)
            .shadow(color: .black, radius: 0, x: -1, y: 0)
            .shadow(color: .black, radius: 0, x: 0, y: 1)
            .shadow(color: .black, radius: 0, x: 0, y: -1)
            .shadow(color: .black.opacity(0.8), radius: 2, y: 1)
    }
}

/// 当前行：白字描边，已唱部分从左向右铺成绿色
private struct KaraokeLine: View {
    let text: String
    let progress: Double
    let fontSize: CGFloat
    let base: Color
    let played: Color

    var body: some View {
        Text(text)
            .font(.system(size: fontSize, weight: .bold))
            .foregroundStyle(base)
            .lineLimit(1)
            .minimumScaleFactor(0.45)
            .overlay {
                Text(text)
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundStyle(played)
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                    .mask(alignment: .leading) {
                        GeometryReader { proxy in
                            Rectangle()
                                .frame(width: max(0, proxy.size.width * progress))
                        }
                    }
            }
            .shadow(color: .black, radius: 0, x: 1.5, y: 0)
            .shadow(color: .black, radius: 0, x: -1.5, y: 0)
            .shadow(color: .black, radius: 0, x: 0, y: 1.5)
            .shadow(color: .black, radius: 0, x: 0, y: -1.5)
            .shadow(color: .black.opacity(0.85), radius: 3, y: 1)
    }
}
