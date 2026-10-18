//
//  ClassicMainWindow.swift
//  TTPlayer for macOS
//
//  千千静听主窗口：标题、频谱、歌曲信息、进度、控制栏，列表停靠在下面
//

import SwiftUI
import AppKit

struct ClassicMainWindow: View {
    @EnvironmentObject private var manager: PlaybackManager
    @EnvironmentObject private var panels: PanelController
    @EnvironmentObject private var desktopLyric: DesktopLyricManager

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            playbackStage
            ClassicProgressBar(
                current: manager.player.currentTime,
                total: manager.player.duration,
                onSeek: { manager.player.seek(to: $0) }
            )
            ClassicControlBar(manager: manager)

            if panels.playlistDocked {
                ClassicPlaylistView(
                    playlist: manager.playlist,
                    currentTrack: Binding(
                        get: { manager.player.currentTrack },
                        set: { manager.player.currentTrack = $0 }
                    ),
                    onTrackSelected: { manager.play(track: $0) },
                    onImport: { urls in
                        Task { await manager.importTracks(from: urls) }
                    },
                    onClear: { manager.clearPlaylist() }
                )
                .frame(maxHeight: .infinity)
            }
        }
        .frame(minWidth: 460, maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(TTPlayerClassicColors.mainBackground)
        .background(PlayerWindowHost(playlistDocked: panels.playlistDocked, pinned: panels.pinned))
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
            return true
        }
        .onChange(of: manager.player.currentTime) { _, _ in
            pushDesktopLyric()
        }
        .onChange(of: manager.lyricSync.currentLine?.text) { _, _ in
            pushDesktopLyric()
        }
        .onChange(of: desktopLyric.isVisible) { _, visible in
            if visible {
                pushDesktopLyric()
            }
        }
    }

    private var coverSide: CGFloat {
        PlayerMetrics.spectrum + PlayerMetrics.info
    }

    private var coverImage: NSImage? {
        guard let data = manager.player.currentTrack?.artworkData else { return nil }
        return NSImage(data: data)
    }

    /// 有封面时放在频谱和歌曲信息左侧，没有封面时频谱仍铺满宽度
    private var playbackStage: some View {
        HStack(spacing: 0) {
            if let coverImage {
                Image(nsImage: coverImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: coverSide, height: coverSide)
                    .clipped()
            }

            VStack(spacing: 0) {
                EnhancedSpectrumView(analyzer: manager.player.analyzer)
                    .frame(height: PlayerMetrics.spectrum)
                infoBar
            }
        }
        .frame(height: coverSide)
    }

    private var titleBar: some View {
        HStack(spacing: 8) {
            Text("千千静听")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(TTPlayerClassicColors.accent)

            Text(manager.player.currentTrack?.displayName ?? "未播放")
                .font(.system(size: 12))
                .foregroundColor(TTPlayerClassicColors.primaryText)
                .lineLimit(1)

            Spacer(minLength: 8)

            ClassicButton(title: "顶", isActive: panels.pinned) {
                panels.setPinned(!panels.pinned)
            }
            .help("总在最前")

            Button(action: minimize) {
                Text("—")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(TTPlayerClassicColors.primaryText)
                    .frame(width: 22, height: 16)
            }
            .buttonStyle(.plain)
            .help("最小化")

            Button(action: { NSApp.terminate(nil) }) {
                Text("×")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(TTPlayerClassicColors.primaryText)
                    .frame(width: 22, height: 16)
            }
            .buttonStyle(.plain)
            .help("退出")
        }
        .padding(.horizontal, 8)
        .frame(height: PlayerMetrics.title)
        .background(TTPlayerClassicColors.titleBar)
    }

    private var infoBar: some View {
        HStack {
            Text(infoText)
                .font(.system(size: 11))
                .foregroundColor(TTPlayerClassicColors.secondaryText)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 8)
        .frame(height: PlayerMetrics.info)
        .background(TTPlayerClassicColors.secondaryBackground)
    }

    private var infoText: String {
        if let line = manager.lyricSync.currentLine?.text, !line.isEmpty {
            return line
        }
        if let track = manager.player.currentTrack {
            let pieces = [track.artist, track.album].compactMap { $0 }.filter { !$0.isEmpty }
            if !pieces.isEmpty {
                return pieces.joined(separator: " · ")
            }
        }
        return "打开文件开始播放"
    }

    private func minimize() {
        NSApp.keyWindow?.miniaturize(nil)
    }

    private func pushDesktopLyric() {
        guard desktopLyric.isVisible else { return }
        desktopLyric.update(
            currentLine: manager.lyricSync.currentLine?.text ?? "",
            nextLine: manager.lyricSync.nextLine?.text ?? "",
            progress: manager.lyricSync.progress
        )
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                guard let url, error == nil else { return }
                Task {
                    await manager.importTracks(from: [url])
                }
            }
        }
    }
}
