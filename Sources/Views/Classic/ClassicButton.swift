//
//  ClassicButton.swift
//  TTPlayer for macOS
//
//  千千静听风格的斜面小按钮和控制栏
//

import SwiftUI

enum PlayerGlyph {
    case previous
    case play
    case pause
    case stop
    case next
    case open
    case list
    case lyric
    case equalizer
    case pin
    case volume
    case mute
}

/// 斜面小按钮，尺寸对齐原版控制条，不用系统符号
struct ClassicButton: View {
    var glyph: PlayerGlyph? = nil
    var title: String? = nil
    var isLarge: Bool = false
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(isActive ? TTPlayerClassicColors.accent.opacity(0.28) : Color.white.opacity(0.06))
                RoundedRectangle(cornerRadius: 2)
                    .stroke(TTPlayerClassicColors.bevelDark, lineWidth: 1)
                RoundedRectangle(cornerRadius: 2)
                    .stroke(TTPlayerClassicColors.bevelLight, lineWidth: 1)
                    .padding(1)
                    .mask(
                        VStack(spacing: 0) {
                            Rectangle().frame(height: isLarge ? 14 : 10)
                            Spacer(minLength: 0)
                        }
                    )

                if let title {
                    Text(title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(isActive ? TTPlayerClassicColors.accent : TTPlayerClassicColors.primaryText)
                        .lineLimit(1)
                } else if let glyph {
                    let color = isActive ? TTPlayerClassicColors.accent : TTPlayerClassicColors.primaryText
                    PlayerGlyphShape(glyph: glyph)
                        .fill(color)
                        .overlay(
                            PlayerGlyphShape(glyph: glyph)
                                .stroke(color, style: StrokeStyle(lineWidth: 1.3, lineJoin: .round))
                        )
                        .frame(width: isLarge ? 12 : 10, height: isLarge ? 12 : 10)
                }
            }
            .frame(width: title == nil ? (isLarge ? 32 : 24) : 36, height: isLarge ? 28 : 22)
        }
        .buttonStyle(.plain)
    }
}

/// 用描边画出播放器图标
struct PlayerGlyphShape: Shape {
    let glyph: PlayerGlyph

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch glyph {
        case .play:
            path.move(to: CGPoint(x: rect.minX + 2, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX + 2, y: rect.maxY))
            path.closeSubpath()
        case .pause:
            let w = rect.width * 0.28
            path.addRect(CGRect(x: rect.minX, y: rect.minY, width: w, height: rect.height))
            path.addRect(CGRect(x: rect.maxX - w, y: rect.minY, width: w, height: rect.height))
        case .stop:
            path.addRect(rect.insetBy(dx: 1, dy: 1))
        case .previous:
            path.addRect(CGRect(x: rect.minX, y: rect.minY, width: 1.8, height: rect.height))
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + 3, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.closeSubpath()
        case .next:
            path.addRect(CGRect(x: rect.maxX - 1.8, y: rect.minY, width: 1.8, height: rect.height))
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - 3, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        case .open:
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY - 1))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.midY - 1))
            path.addLine(to: CGPoint(x: rect.midX + 2, y: rect.minY + 1))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + 1))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.closeSubpath()
        case .list:
            for i in 0..<3 {
                let y = rect.minY + CGFloat(i) * rect.height / 2.4
                path.move(to: CGPoint(x: rect.minX, y: y))
                path.addLine(to: CGPoint(x: rect.maxX, y: y))
            }
        case .lyric:
            path.addEllipse(in: CGRect(x: rect.minX, y: rect.midY, width: rect.width * 0.45, height: rect.height * 0.45))
            path.move(to: CGPoint(x: rect.minX + rect.width * 0.4, y: rect.midY + rect.height * 0.2))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.4, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + 2))
        case .equalizer:
            let heights: [CGFloat] = [0.45, 0.9, 0.6, 0.75]
            let slot = rect.width / CGFloat(heights.count)
            for (i, h) in heights.enumerated() {
                let barH = rect.height * h
                path.addRect(CGRect(
                    x: rect.minX + CGFloat(i) * slot + 0.5,
                    y: rect.maxY - barH,
                    width: slot - 1.5,
                    height: barH
                ))
            }
        case .pin:
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.move(to: CGPoint(x: rect.minX + 1, y: rect.minY + 3))
            path.addLine(to: CGPoint(x: rect.maxX - 1, y: rect.minY + 3))
            path.move(to: CGPoint(x: rect.midX - 3, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.midX + 3, y: rect.midY))
        case .volume:
            path.move(to: CGPoint(x: rect.minX, y: rect.midY - 2))
            path.addLine(to: CGPoint(x: rect.midX - 1, y: rect.midY - 2))
            path.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.midX - 1, y: rect.midY + 2))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY + 2))
            path.closeSubpath()
        case .mute:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        return path
    }
}

/// 主窗口控制栏：上一曲、播放、停止、下一曲、打开、音量、模式、列表、歌词、均衡器
struct ClassicControlBar: View {
    @ObservedObject var manager: PlaybackManager
    @EnvironmentObject private var panels: PanelController
    @EnvironmentObject private var desktopLyric: DesktopLyricManager

    var body: some View {
        HStack(spacing: 4) {
            ClassicButton(glyph: .previous) {
                manager.playPrevious()
            }
            .help("上一首")
            ClassicButton(
                glyph: manager.player.isPlaying ? .pause : .play,
                isLarge: true
            ) {
                manager.togglePlayPause()
            }
            ClassicButton(glyph: .stop) {
                manager.player.stop()
            }
            ClassicButton(glyph: .next) {
                manager.playNext()
            }
            .help("下一首")
            ClassicButton(glyph: .open) {
                openFilePicker()
            }
            .help("打开文件或文件夹")

            Spacer(minLength: 6)

            Button(action: manager.toggleMute) {
                PlayerGlyphShape(glyph: manager.player.isMuted ? .mute : .volume)
                    .stroke(TTPlayerClassicColors.primaryText, lineWidth: 1.2)
                    .frame(width: 12, height: 10)
            }
            .buttonStyle(.plain)

            Slider(value: Binding(
                get: { Double(manager.player.volume) },
                set: { manager.player.setVolume(Float($0)) }
            ), in: 0...1)
                .controlSize(.mini)
                .frame(width: 72)
                .tint(TTPlayerClassicColors.accent)

            ClassicButton(title: modeTitle, isActive: manager.playlist.playMode != .sequential) {
                manager.cyclePlayMode()
            }
            .help(manager.playlist.playMode.rawValue)

            ClassicButton(glyph: .list, isActive: panels.playlistDocked) {
                panels.playlistDocked.toggle()
            }
            .help("播放列表")

            ClassicButton(glyph: .lyric, isActive: panels.lyricsOpen) {
                panels.toggleLyrics(syncEngine: manager.lyricSync, manager: manager)
            }
            .help("歌词")

            ClassicButton(glyph: .equalizer, isActive: panels.equalizerOpen) {
                panels.toggleEqualizer(equalizer: manager.equalizer)
            }
            .help("均衡器")

            ClassicButton(title: "桌词", isActive: desktopLyric.isVisible) {
                desktopLyric.toggle()
            }
            .help("桌面歌词")
        }
        .padding(.horizontal, 8)
        .frame(height: PlayerMetrics.controls)
        .background(TTPlayerClassicColors.controlBackground)
    }

    private var modeTitle: String {
        switch manager.playlist.playMode {
        case .sequential: return "顺序"
        case .repeatAll: return "列表"
        case .repeatOne: return "单曲"
        case .shuffle: return "随机"
        }
    }

    private func openFilePicker() {
        FileOpener.openAudioFiles { urls in
            guard !urls.isEmpty else { return }
            Task {
                await manager.importTracks(from: urls)
            }
        }
    }
}
