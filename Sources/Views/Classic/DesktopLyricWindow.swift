//
//  DesktopLyricWindow.swift
//  TTPlayer for macOS
//
//  桌面歌词窗口
//

import SwiftUI
import AppKit

/// 桌面歌词窗口（浮动、置顶、半透明）
class DesktopLyricWindow: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 100, y: 100, width: 800, height: 120),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // 窗口属性
        level = .floating  // 始终置顶
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true

        // 显示在所有空间
        collectionBehavior = [.canJoinAllSpaces, .stationary]

        // 初始居中
        center()
    }

    /// 设置是否可拖动
    func setDraggable(_ draggable: Bool) {
        isMovableByWindowBackground = draggable
        ignoresMouseEvents = !draggable
    }
}

/// 桌面歌词视图（描边样式）
struct DesktopLyricView: View {
    let line: String
    @State private var isDragging = false

    var body: some View {
        ZStack {
            // 描边效果（8方向）
            ForEach(offsets, id: \.self) { offset in
                Text(line)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .offset(x: offset.x, y: offset.y)
            }

            // 主文字（白色）
            Text(line)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 4)
        }
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial.opacity(0.5))
        )
        .onHover { hovering in
            isDragging = hovering
        }
    }

    // 8方向描边偏移
    private let offsets: [CGPoint] = [
        CGPoint(x: -2, y: -2),
        CGPoint(x:  0, y: -2),
        CGPoint(x:  2, y: -2),
        CGPoint(x: -2, y:  0),
        CGPoint(x:  2, y:  0),
        CGPoint(x: -2, y:  2),
        CGPoint(x:  0, y:  2),
        CGPoint(x:  2, y:  2),
    ]
}

/// 卡拉OK效果视图（逐字高亮）
struct KaraokeLyricView: View {
    let line: String
    let progress: Double  // 0.0 ~ 1.0

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 底层：未播放部分（灰色描边）
                outlinedText(line, color: .gray)

                // 顶层：已播放部分（彩色渐变）
                outlinedText(line, color: .clear)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .mask(
                        Rectangle()
                            .frame(width: geometry.size.width * progress)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    )
            }
        }
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial.opacity(0.5))
        )
    }

    @ViewBuilder
    private func outlinedText(_ text: String, color: Color) -> some View {
        ZStack {
            // 描边
            ForEach([-2, -1, 0, 1, 2], id: \.self) { x in
                ForEach([-2, -1, 0, 1, 2], id: \.self) { y in
                    if x != 0 || y != 0 {
                        Text(text)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                            .offset(x: CGFloat(x), y: CGFloat(y))
                    }
                }
            }

            // 主文字
            Text(text)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
    }
}

// MARK: - Preview

struct DesktopLyricView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            DesktopLyricView(line: "对这个世界如果你有太多的抱怨")
                .preferredColorScheme(.dark)

            KaraokeLyricView(
                line: "跌倒了就不敢继续往前走",
                progress: 0.6
            )
            .preferredColorScheme(.dark)
        }
        .frame(width: 800)
    }
}
