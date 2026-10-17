//
//  FixedMainWindow.swift
//  TTPlayer for macOS
//
//  修复后的主窗口（所有按钮可用）
//

import SwiftUI

/// 修复后的主窗口
struct FixedMainWindow: View {
    @StateObject private var manager = PlaybackManager()
    @StateObject private var desktopLyric = DesktopLyricManager()
    @StateObject private var hotkeyManager = GlobalHotkeyManager()

    @State private var showPlaylist = false
    @State private var showLyrics = false
    @State private var showEqualizer = false

    var body: some View {
        VStack(spacing: 0) {
            // 频谱可视化
            EnhancedSpectrumView(analyzer: manager.player.analyzer)
                .frame(height: 60)

            // 歌曲信息区
            HStack {
                Text(manager.player.currentTrack?.displayName ?? "TTPlayer for macOS - 请打开文件")
                    .font(.system(size: 12))
                    .foregroundColor(TTPlayerClassicColors.primaryText)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 8)
            .frame(height: 20)
            .background(TTPlayerClassicColors.secondaryBackground)

            // 进度条
            ClassicProgressBar(
                current: manager.player.currentTime,
                total: manager.player.duration,
                onSeek: { time in
                    manager.player.seek(to: time)
                }
            )
            .frame(height: 24)

            // 控制栏
            ClassicControlBar(
                manager: manager,
                showPlaylist: $showPlaylist,
                showEqualizer: $showEqualizer
            )
        }
        .frame(width: 327, height: 141)
        .background(TTPlayerClassicColors.mainBackground)
        .onAppear {
            setupHotkeys()
        }
        // 播放列表窗口
        .sheet(isPresented: $showPlaylist) {
            ClassicPlaylistView(
                playlist: manager.playlist,
                currentTrack: .constant(manager.player.currentTrack)
            ) { track in
                manager.play(track: track)
            }
            .frame(width: 400, height: 600)
        }
        // 歌词窗口
        .sheet(isPresented: $showLyrics) {
            ClassicLyricWindow(syncEngine: manager.lyricSync)
        }
        // 均衡器窗口
        .sheet(isPresented: $showEqualizer) {
            ClassicEqualizerWindow(equalizer: manager.player.equalizer)
        }
        // 拖拽文件支持
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
            return true
        }
    }

    // MARK: - Hotkeys

    private func setupHotkeys() {
        hotkeyManager.registerDefaultHotkeys(
            onPlayPause: {
                manager.player.togglePlayPause()
            },
            onNext: {
                manager.playNext()
            },
            onPrevious: {
                manager.playPrevious()
            },
            onVolumeUp: {
                let newVolume = min(1.0, manager.player.volume + 0.1)
                manager.player.setVolume(newVolume)
            },
            onVolumeDown: {
                let newVolume = max(0.0, manager.player.volume - 0.1)
                manager.player.setVolume(newVolume)
            },
            onShowLyrics: {
                desktopLyric.toggle()
            }
        )
    }

    // MARK: - Drag & Drop

    private func handleDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                guard let url = url, error == nil else { return }

                Task {
                    if let track = await Track.from(url: url) {
                        await MainActor.run {
                            manager.addTrack(track)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Preview

struct FixedMainWindow_Previews: PreviewProvider {
    static var previews: some View {
        FixedMainWindow()
            .preferredColorScheme(.dark)
    }
}
