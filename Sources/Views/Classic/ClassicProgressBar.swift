//
//  ClassicProgressBar.swift
//  TTPlayer for macOS
//
//  经典进度条：左侧已播放时间，细槽，右侧总时长
//

import SwiftUI

struct ClassicProgressBar: View {
    let current: TimeInterval
    let total: TimeInterval
    var onSeek: ((TimeInterval) -> Void)?

    @State private var isDragging = false
    @State private var dragProgress: Double = 0

    private var progress: Double {
        isDragging ? dragProgress : (total > 0 ? current / total : 0)
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(formatTime(isDragging ? dragProgress * total : current))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(TTPlayerClassicColors.accent)
                .frame(width: 36, alignment: .trailing)

            GeometryReader { geometry in
                let width = geometry.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.55))
                        .frame(height: 4)
                    Capsule()
                        .fill(TTPlayerClassicColors.accent)
                        .frame(width: max(0, width * progress), height: 4)
                    Circle()
                        .fill(TTPlayerClassicColors.primaryText)
                        .frame(width: 8, height: 8)
                        .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
                        .offset(x: max(0, min(width - 8, width * progress - 4)))
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            dragProgress = max(0, min(1, value.location.x / max(width, 1)))
                        }
                        .onEnded { value in
                            let ratio = max(0, min(1, value.location.x / max(width, 1)))
                            isDragging = false
                            onSeek?(ratio * total)
                        }
                )
            }
            .frame(height: 14)

            Text(formatTime(total))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(TTPlayerClassicColors.secondaryText)
                .frame(width: 36, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .frame(height: PlayerMetrics.progress)
        .background(TTPlayerClassicColors.secondaryBackground)
    }
}

enum PlayerMetrics {
    static let title: CGFloat = 26
    static let spectrum: CGFloat = 78
    static let info: CGFloat = 20
    static let progress: CGFloat = 22
    static let controls: CGFloat = 36

    static var chrome: CGFloat { title + spectrum + info + progress + controls }
}
