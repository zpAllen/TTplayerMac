//
//  ClassicProgressBar.swift
//  TTPlayer for macOS
//
//  经典进度条组件
//

import SwiftUI

/// 经典进度条
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
        HStack(spacing: 8) {
            // 当前时间
            Text(formatTime(current))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(TTPlayerClassicColors.primaryText)
                .frame(width: 40, alignment: .trailing)

            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景槽
                    RoundedRectangle(cornerRadius: 2)
                        .fill(TTPlayerClassicColors.progressBackground)
                        .frame(height: 4)

                    // 已播放部分
                    RoundedRectangle(cornerRadius: 2)
                        .fill(TTPlayerClassicColors.progressGradient)
                        .frame(
                            width: geometry.size.width * progress,
                            height: 4
                        )

                    // 拖动滑块
                    Circle()
                        .fill(TTPlayerClassicColors.primaryText)
                        .frame(width: 10, height: 10)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                        .offset(x: geometry.size.width * progress - 5)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    isDragging = true
                                    let newProgress = max(0, min(1, value.location.x / geometry.size.width))
                                    dragProgress = newProgress
                                }
                                .onEnded { value in
                                    isDragging = false
                                    let newProgress = max(0, min(1, value.location.x / geometry.size.width))
                                    let newTime = newProgress * total
                                    onSeek?(newTime)
                                }
                        )
                }
            }
            .frame(height: 14)

            // 总时长
            Text(formatTime(total))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(TTPlayerClassicColors.primaryText)
                .frame(width: 40, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .background(TTPlayerClassicColors.secondaryBackground)
    }
}

// MARK: - Preview

struct ClassicProgressBar_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ClassicProgressBar(current: 155, total: 263)
            ClassicProgressBar(current: 0, total: 263)
            ClassicProgressBar(current: 263, total: 263)
        }
        .frame(width: 327)
        .padding()
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
}
