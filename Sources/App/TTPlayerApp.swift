//
//  TTPlayerApp.swift
//  TTPlayer for macOS
//
//  应用入口。菜单和主窗口共用同一个 PlaybackManager。
//

import SwiftUI

@main
struct TTPlayerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var manager = PlaybackManager()
    @StateObject private var panels = PanelController()
    @StateObject private var desktopLyric = DesktopLyricManager()
    @StateObject private var hotkeys = GlobalHotkeyManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ClassicMainWindow()
                .environmentObject(manager)
                .environmentObject(panels)
                .environmentObject(desktopLyric)
                .task {
                    manager.restoreIfNeeded()
                    desktopLyric.loadSettings()
                    registerHotkeysIfNeeded()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active {
                        manager.persist()
                        desktopLyric.saveSettings()
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 480, height: 560)
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandMenu("文件") {
                Button("打开音乐文件或文件夹...") {
                    FileOpener.openAudioFiles { urls in
                        guard !urls.isEmpty else { return }
                        Task { await manager.importTracks(from: urls) }
                    }
                }
                .keyboardShortcut("o", modifiers: .command)

                Divider()

                Button("清空播放列表") {
                    manager.clearPlaylist()
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
            }

            CommandMenu("播放") {
                Button("播放/暂停") {
                    manager.togglePlayPause()
                }
                .keyboardShortcut(.space)

                Button("停止") {
                    manager.player.stop()
                }
                .keyboardShortcut("s", modifiers: .command)

                Divider()

                Button("上一曲") {
                    manager.playPrevious()
                }
                .keyboardShortcut(.leftArrow, modifiers: .command)

                Button("下一曲") {
                    manager.playNext()
                }
                .keyboardShortcut(.rightArrow, modifiers: .command)

                Divider()

                Button("音量增加") {
                    manager.increaseVolume()
                }
                .keyboardShortcut(.upArrow, modifiers: .command)

                Button("音量减小") {
                    manager.decreaseVolume()
                }
                .keyboardShortcut(.downArrow, modifiers: .command)

                Button("静音") {
                    manager.toggleMute()
                }
                .keyboardShortcut("m", modifiers: .command)

                Divider()

                Menu("播放模式") {
                    ForEach(PlayMode.allCases, id: \.self) { mode in
                        Button(mode.rawValue) {
                            manager.playlist.playMode = mode
                            manager.persist()
                        }
                    }
                }
            }

            CommandMenu("窗口") {
                Button("播放列表") {
                    panels.playlistDocked.toggle()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])

                Button("歌词") {
                    panels.toggleLyrics(syncEngine: manager.lyricSync, manager: manager)
                }
                .keyboardShortcut("l", modifiers: .command)

                Button("均衡器") {
                    panels.toggleEqualizer(equalizer: manager.equalizer)
                }
                .keyboardShortcut("e", modifiers: .command)

                Button("桌面歌词") {
                    desktopLyric.toggle()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])

                Divider()

                Button(panels.pinned ? "取消置顶" : "总在最前") {
                    panels.setPinned(!panels.pinned)
                }
            }
        }
    }

    private func registerHotkeysIfNeeded() {
        hotkeys.registerDefaultHotkeys(
            onPlayPause: { manager.togglePlayPause() },
            onNext: { manager.playNext() },
            onPrevious: { manager.playPrevious() },
            onVolumeUp: { manager.increaseVolume() },
            onVolumeDown: { manager.decreaseVolume() },
            onShowLyrics: { desktopLyric.toggle() }
        )
    }
}
