//
//  ClassicMainWindow.swift
//  TTPlayer for macOS
//
//  千千静听主窗口：标题、频谱、歌曲信息、进度、控制栏，列表停靠在下面
//

import SwiftUI
import AppKit

private struct PlayerWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct ClassicMainWindow: View {
    @EnvironmentObject private var manager: PlaybackManager
    @EnvironmentObject private var panels: PanelController
    @EnvironmentObject private var desktopLyric: DesktopLyricManager
    @EnvironmentObject private var skins: SkinLibrary
    @State private var contentWidth: CGFloat = 0

    private var activeSkin: LoadedWindow? {
        skins.skin?.player
    }

    var body: some View {
        VStack(spacing: 0) {
            if let activeSkin {
                let width = contentWidth > 1 ? contentWidth : activeSkin.size.width
                let height = width * activeSkin.size.height / activeSkin.size.width
                SkinPlayerView(
                    window: activeSkin,
                    snapshot: skinSnapshot,
                    analyzer: manager.player.analyzer,
                    onButton: handleSkinButton,
                    onSeek: { manager.player.seek(to: $0) },
                    onVolume: { manager.player.setVolume($0) }
                )
                .frame(width: width, height: height)
            } else {
                titleBar
                playbackStage
                ClassicProgressBar(
                current: manager.player.currentTime,
                total: manager.player.duration,
                onSeek: { manager.player.seek(to: $0) }
            )
                ClassicControlBar(manager: manager)
            }

            if panels.lyricsDocked {
                ClassicLyricWindow(syncEngine: manager.lyricSync, embedded: true) {
                    panels.popOutLyrics(
                        syncEngine: manager.lyricSync,
                        manager: manager,
                        desktopLyric: desktopLyric
                    )
                }
                .frame(maxHeight: .infinity)
            }

            if panels.equalizerDocked {
                ClassicEqualizerWindow(equalizer: manager.equalizer, embedded: true) {
                    panels.popOutEqualizer(equalizer: manager.equalizer)
                }
                .frame(maxHeight: .infinity)
            }

            ClassicPlaylistView(
                playlist: manager.playlist,
                lists: manager.playlists,
                currentTrackID: manager.player.currentTrack?.id,
                onTrackSelected: { manager.play(track: $0) },
                onImport: { urls in
                    Task { await manager.importTracks(from: urls) }
                },
                onClear: { manager.clearPlaylist() },
                onSelectList: { manager.selectPlaylist(id: $0) },
                onCreateList: { manager.createPlaylist(named: $0) },
                onDeleteList: { manager.deletePlaylist(id: $0) },
                onImportList: { url in
                    Task { await manager.importPlaylistFile(from: url) }
                },
                onExportList: { url in
                    try? manager.exportPlaylist(to: url)
                },
                onCyclePlayMode: { manager.cyclePlayMode() }
            )
            .id(manager.playlist.id)
            .frame(minHeight: 0, maxHeight: panels.playlistDocked ? .infinity : 0)
            .clipped()
            .allowsHitTesting(panels.playlistDocked)
            .accessibilityHidden(!panels.playlistDocked)
        }
        .frame(
            minWidth: activeSkin?.size.width ?? 460,
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .top
        )
        .background(activeSkin == nil ? TTPlayerClassicColors.mainBackground : Color.clear)
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: PlayerWidthKey.self, value: proxy.size.width)
            }
        }
        .onPreferenceChange(PlayerWidthKey.self) { newWidth in
            // 宽度在布局过程中写回状态，会让正在排版的窗口再改约束，双击列表就会崩。
            guard newWidth > 1, abs(newWidth - contentWidth) > 0.5 else { return }
            DispatchQueue.main.async {
                if abs(newWidth - self.contentWidth) > 0.5 {
                    self.contentWidth = newWidth
                }
            }
        }
        .ignoresSafeArea()
        .background(PlayerWindowHost(
            playlistDocked: bottomDocked,
            pinned: panels.pinned,
            skinSize: activeSkin?.size
        ))
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

    /// 列表、歌词、均衡器共用播放器下面这一块，窗口高度不随切换跳动。
    private var bottomDocked: Bool {
        panels.playlistDocked || panels.lyricsDocked || panels.equalizerDocked
    }

    private var skinSnapshot: SkinSnapshot {
        let track = manager.player.currentTrack
        let status: String
        if manager.player.isPlaying {
            status = "播放"
        } else if manager.player.canResume, manager.player.currentTime > 0 {
            status = "暂停"
        } else {
            status = "停止"
        }
        let count = manager.playlist.tracks.count
        return SkinSnapshot(
            isPlaying: manager.player.isPlaying,
            isMuted: manager.player.isMuted,
            time: manager.player.currentTime,
            duration: manager.player.duration,
            volume: manager.player.volume,
            title: track?.displayName ?? "千千静听",
            status: status,
            playlistOn: panels.playlistDocked,
            lyricsOn: panels.lyricsDocked || panels.lyricsOpen,
            equalizerOn: panels.equalizerDocked || panels.equalizerOpen,
            desktopLyricOn: desktopLyric.isVisible,
            canPrev: count > 0 && manager.playlist.currentIndex > 0,
            canNext: count > 0 && manager.playlist.currentIndex < count - 1
        )
    }

    private func handleSkinButton(_ id: String) {
        switch id {
        case "play", "pause":
            manager.togglePlayPause()
        case "prev":
            manager.playPrevious()
        case "next":
            manager.playNext()
        case "stop":
            manager.player.stop()
        case "open":
            FileOpener.openAudioFiles { urls in
                guard !urls.isEmpty else { return }
                Task { await manager.importTracks(from: urls) }
            }
        case "mute":
            manager.toggleMute()
        case "lyric":
            panels.toggleLyrics(syncEngine: manager.lyricSync, manager: manager, desktopLyric: desktopLyric)
        case "equalizer":
            panels.toggleEqualizer(equalizer: manager.equalizer)
        case "playlist":
            panels.togglePlaylist()
        case "minimize":
            NSApp.keyWindow?.miniaturize(nil)
        case "exit":
            NSApp.terminate(nil)
        case "browser":
            desktopLyric.toggle()
        default:
            break
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
