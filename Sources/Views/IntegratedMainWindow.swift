//
//  IntegratedMainWindow.swift
//  TTPlayer for macOS
//
//  集成所有功能的完整主窗口
//

import SwiftUI

/// 完整集成的主窗口
struct IntegratedMainWindow: View {
    // MARK: - State Objects

    @StateObject private var player = EnhancedAudioPlayer()
    @StateObject private var playlist = Playlist(name: "默认列表")
    @StateObject private var playlistManager = PlaylistManager()
    @StateObject private var lyricSync = LyricSyncEngine()
    @StateObject private var desktopLyric = DesktopLyricManager()
    @StateObject private var hotkeyManager = GlobalHotkeyManager()

    // MARK: - State

    @State private var showPlaylist = false
    @State private var showLyrics = false
    @State private var showEqualizer = false

    var body: some View {
        VStack(spacing: 0) {
            // 频谱可视化
            EnhancedSpectrumView(analyzer: player.analyzer)
                .frame(height: 60)

            // 歌曲信息区
            songInfoBar

            // 进度条
            ClassicProgressBar(
                current: player.currentTime,
                total: player.duration,
                onSeek: { time in
                    player.seek(to: time)
                }
            )
            .frame(height: 24)

            // 控制栏
            IntegratedControlBar(
                player: player,
                playlist: playlist,
                showPlaylist: $showPlaylist,
                showLyrics: $showLyrics,
                showEqualizer: $showEqualizer,
                desktopLyric: desktopLyric
            )
        }
        .frame(width: 327, height: 141)
        .background(TTPlayerClassicColors.mainBackground)
        .onAppear {
            setupPlayer()
            setupHotkeys()
        }
        .sheet(isPresented: $showPlaylist) {
            ClassicPlaylistView(
                playlist: playlist,
                currentTrack: $player.currentTrack,
                onTrackSelected: { track in
                    loadAndPlay(track)
                }
            )
            .frame(width: 400, height: 600)
        }
        .sheet(isPresented: $showLyrics) {
            ClassicLyricWindow(syncEngine: lyricSync)
        }
        .sheet(isPresented: $showEqualizer) {
            ClassicEqualizerWindow(equalizer: player.equalizer)
        }
    }

    // MARK: - Song Info Bar

    private var songInfoBar: some View {
        HStack {
            Text(player.currentTrack?.displayName ?? "TTPlayer for macOS")
                .font(.system(size: 12))
                .foregroundColor(TTPlayerClassicColors.primaryText)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 8)
        .frame(height: 20)
        .background(TTPlayerClassicColors.secondaryBackground)
    }

    // MARK: - Setup

    private func setupPlayer() {
        // 连接歌词同步
        lyricSync.connect(to: player)

        // 选择第一个播放列表
        if let first = playlistManager.playlists.first {
            playlistManager.selectPlaylist(first)
        }
    }

    private func setupHotkeys() {
        hotkeyManager.registerDefaultHotkeys(
            onPlayPause: {
                player.togglePlayPause()
            },
            onNext: {
                if let next = playlist.next() {
                    loadAndPlay(next)
                }
            },
            onPrevious: {
                if let prev = playlist.previous() {
                    loadAndPlay(prev)
                }
            },
            onVolumeUp: {
                let newVolume = min(1.0, player.volume + 0.1)
                player.setVolume(newVolume)
            },
            onVolumeDown: {
                let newVolume = max(0.0, player.volume - 0.1)
                player.setVolume(newVolume)
            },
            onShowLyrics: {
                desktopLyric.toggle()
            }
        )
    }

    private func loadAndPlay(_ track: Track) {
        player.load(track: track)
        player.play()

        // 自动加载歌词
        Task {
            let searchEngine = LyricSearchEngine()
            if let doc = await searchEngine.autoLoadLyrics(for: track) {
                await MainActor.run {
                    lyricSync.load(document: doc)
                }
            }
        }
    }
}

/// 集成控制栏
struct IntegratedControlBar: View {
    @ObservedObject var player: EnhancedAudioPlayer
    @ObservedObject var playlist: Playlist
    @Binding var showPlaylist: Bool
    @Binding var showLyrics: Bool
    @Binding var showEqualizer: Bool
    @ObservedObject var desktopLyric: DesktopLyricManager

    var body: some View {
        HStack(spacing: 12) {
            // 上一曲
            ClassicButton(icon: "backward.fill") {
                if let prev = playlist.previous() {
                    player.load(track: prev)
                    player.play()
                }
            }

            // 播放/暂停
            ClassicButton(
                icon: player.isPlaying ? "pause.fill" : "play.fill",
                isLarge: true
            ) {
                player.togglePlayPause()
            }

            // 下一曲
            ClassicButton(icon: "forward.fill") {
                if let next = playlist.next() {
                    player.load(track: next)
                    player.play()
                }
            }

            // 停止
            ClassicButton(icon: "stop.fill") {
                player.stop()
            }

            // 打开文件
            ClassicButton(icon: "folder") {
                openFiles()
            }

            Spacer()

            // 音量控制
            HStack(spacing: 4) {
                Button(action: { player.toggleMute() }) {
                    Image(systemName: player.isMuted ? "speaker.slash.fill" : "speaker.wave.1.fill")
                        .font(.system(size: 12))
                        .foregroundColor(TTPlayerClassicColors.primaryText)
                }
                .buttonStyle(.plain)

                Slider(value: Binding(
                    get: { Double(player.volume) },
                    set: { player.setVolume(Float($0)) }
                ), in: 0...1)
                    .frame(width: 60)
                    .tint(TTPlayerClassicColors.accent)

                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 12))
                    .foregroundColor(TTPlayerClassicColors.primaryText)
            }

            Spacer()

            // 播放列表
            ClassicButton(icon: "music.note.list", isActive: showPlaylist) {
                showPlaylist.toggle()
            }

            // 歌词
            ClassicButton(icon: "text.quote", isActive: showLyrics || desktopLyric.isVisible) {
                if showLyrics {
                    showLyrics = false
                    desktopLyric.show()
                } else if desktopLyric.isVisible {
                    desktopLyric.hide()
                } else {
                    showLyrics = true
                }
            }

            // 均衡器
            ClassicButton(icon: "slider.horizontal.3", isActive: showEqualizer) {
                showEqualizer.toggle()
            }

            // 设置
            ClassicButton(icon: "gearshape.fill") {
                // TODO: 打开设置
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 40)
        .background(TTPlayerClassicColors.controlBackground)
    }

    private func openFiles() {
        FileOpener.openAudioFiles { urls in
            Task {
                for url in urls {
                    if let track = await Track.from(url: url) {
                        await MainActor.run {
                            playlist.add(track: track)

                            // 如果没有正在播放的，自动播放第一首
                            if player.currentTrack == nil {
                                player.load(track: track)
                                player.play()
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Preview

struct IntegratedMainWindow_Previews: PreviewProvider {
    static var previews: some View {
        IntegratedMainWindow()
            .preferredColorScheme(.dark)
    }
}
