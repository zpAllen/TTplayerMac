//
//  ClassicLyricWindow.swift
//  TTPlayer for macOS
//
//  经典歌词窗口
//

import SwiftUI
import AppKit

/// 经典歌词窗口视图
struct ClassicLyricWindow: View {
    @ObservedObject var syncEngine: LyricSyncEngine
    @EnvironmentObject private var manager: PlaybackManager
    @EnvironmentObject private var desktopLyric: DesktopLyricManager
    var embedded = false
    var onPopOut: (() -> Void)? = nil
    @AppStorage("desktop.fontSize") private var fontSize = 34.0
    @AppStorage("desktop.color") private var colorName = DesktopLyricColor.white.rawValue
    @AppStorage("desktop.opacity") private var opacity = 1.0

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            lyricTools
            lyricScrollView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TTPlayerClassicColors.mainBackground)
    }

    // MARK: - Title Bar

    private var titleBar: some View {
        HStack {
            Text("歌词")
                .font(.system(size: 11))
                .foregroundColor(TTPlayerClassicColors.primaryText)

            Spacer()

            Button("指定歌词") {
                FileOpener.openLyricFile { url in
                    guard let url else { return }
                    manager.useLyricFile(url)
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 10))
            .foregroundColor(TTPlayerClassicColors.accent)
            .help("为当前歌曲选择一个 LRC 歌词文件")

            Button("存为 LRC") {
                saveLyrics()
            }
            .buttonStyle(.plain)
            .font(.system(size: 10))
            .foregroundColor(TTPlayerClassicColors.accent)
            .help("把当前歌词按听到的时间存成 LRC，不改音频文件")

            Button(desktopLyric.isVisible ? "关闭桌面歌词" : "桌面歌词") {
                desktopLyric.toggle()
            }
            .buttonStyle(.plain)
            .font(.system(size: 10))
            .foregroundColor(desktopLyric.isVisible ? TTPlayerClassicColors.accent : TTPlayerClassicColors.primaryText)
            .help("在屏幕底部显示或关掉桌面歌词")

            if embedded {
                PopOutButton(help: "在单独窗口打开歌词", action: { onPopOut?() })
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(TTPlayerClassicColors.controlBackground)
    }

    private var lyricTools: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("偏移")
                    .font(.system(size: 10))
                    .foregroundColor(TTPlayerClassicColors.secondaryText)
                Text(String(format: "%+.1f 秒", syncEngine.userOffset))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(TTPlayerClassicColors.primaryText)
                    .frame(width: 58, alignment: .leading)
                Slider(
                    value: Binding(
                        get: { syncEngine.userOffset },
                        set: { syncEngine.setUserOffset($0) }
                    ),
                    in: -10...10
                )
                .controlSize(.mini)
                Button("归零") {
                    syncEngine.setUserOffset(0)
                }
                .buttonStyle(.borderless)
                .font(.system(size: 10))
            }

            HStack(spacing: 8) {
                Text("字号")
                    .font(.system(size: 10))
                    .foregroundColor(TTPlayerClassicColors.secondaryText)
                Stepper(value: $fontSize, in: 18...48, step: 2) {
                    Text("\(Int(fontSize))")
                        .font(.system(size: 10, design: .monospaced))
                        .frame(width: 24)
                }
                .font(.system(size: 10))
                Picker("颜色", selection: $colorName) {
                    ForEach(DesktopLyricColor.allCases) { item in
                        Text(item.title).tag(item.rawValue)
                    }
                }
                .labelsHidden()
                .frame(width: 72)
                Slider(value: $opacity, in: 0.35...1)
                    .controlSize(.mini)
                    .frame(width: 72)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(TTPlayerClassicColors.secondaryBackground)
    }

    private func saveLyrics() {
        guard let text = syncEngine.exportedLRC() else { return }
        let suggested = (manager.player.currentTrack?.title ?? "歌词") + ".lrc"
        FileOpener.saveLyric(suggestedName: suggested) { url in
            guard let url else { return }
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Lyric View

    private var lyricScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 20) {
                    if let data = manager.player.currentTrack?.artworkData,
                       let image = NSImage(data: data) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 180, height: 180)
                            .padding(.top, 12)
                    }

                    // 显示元数据
                    if let metadata = syncEngine.metadata {
                        metadataView(metadata)
                            .padding(.top, 20)
                    }

                    // 歌词行
                    ForEach(Array(syncEngine.allLines.enumerated()), id: \.element.id) { index, line in
                        Text(line.text)
                            .font(.system(size: 16))
                            .foregroundColor(
                                index == syncEngine.currentIndex
                                    ? TTPlayerClassicColors.accent
                                    : TTPlayerClassicColors.secondaryText
                            )
                            .fontWeight(index == syncEngine.currentIndex ? .bold : .regular)
                            .id(line.id)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: syncEngine.currentIndex) { _, newIndex in
                guard let newIndex = newIndex,
                      newIndex < syncEngine.allLines.count else {
                    return
                }

                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(syncEngine.allLines[newIndex].id, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    private func metadataView(_ metadata: LRCMetadata) -> some View {
        VStack(spacing: 4) {
            if let title = metadata.title {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(TTPlayerClassicColors.primaryText)
            }

            if let artist = metadata.artist {
                Text(artist)
                    .font(.system(size: 14))
                    .foregroundColor(TTPlayerClassicColors.secondaryText)
            }

            if let album = metadata.album {
                Text(album)
                    .font(.system(size: 12))
                    .foregroundColor(TTPlayerClassicColors.tertiaryText)
            }
        }
        .padding(.bottom, 20)
    }

}

// MARK: - Preview

struct ClassicLyricWindow_Previews: PreviewProvider {
    static var previews: some View {
        ClassicLyricWindow(syncEngine: LyricSyncEngine())
            .environmentObject(PlaybackManager())
            .environmentObject(DesktopLyricManager())
            .preferredColorScheme(.dark)
    }
}
