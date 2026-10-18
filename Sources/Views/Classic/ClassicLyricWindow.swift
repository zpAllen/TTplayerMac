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

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            titleBar

            // 歌词显示区
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
        }
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(TTPlayerClassicColors.controlBackground)
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
            .preferredColorScheme(.dark)
    }
}
