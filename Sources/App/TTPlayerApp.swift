//
//  TTPlayerApp.swift
//  TTPlayer for macOS
//
//  应用入口
//

import SwiftUI

@main
struct TTPlayerApp: App {
    @StateObject private var manager = PlaybackManager()

    var body: some Scene {
        WindowGroup {
            ClassicMainWindow()
                .environmentObject(manager)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 327, height: 141)
        .commands {
            // 移除默认的"新建窗口"菜单项
            CommandGroup(replacing: .newItem) {}

            // 文件菜单
            CommandMenu("文件") {
                Button("打开音乐文件...") {
                    openFilePicker()
                }
                .keyboardShortcut("o", modifiers: .command)

                Divider()

                Button("清空播放列表") {
                    manager.clearPlaylist()
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
            }

            // 播放控制菜单
            CommandMenu("播放") {
                Button("播放/暂停") {
                    manager.player.togglePlayPause()
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
                    manager.player.toggleMute()
                }
                .keyboardShortcut("m", modifiers: .command)

                Divider()

                Menu("播放模式") {
                    Button(PlayMode.sequential.rawValue) {
                        manager.playlist.playMode = .sequential
                    }
                    Button(PlayMode.repeatAll.rawValue) {
                        manager.playlist.playMode = .repeatAll
                    }
                    Button(PlayMode.repeatOne.rawValue) {
                        manager.playlist.playMode = .repeatOne
                    }
                    Button(PlayMode.shuffle.rawValue) {
                        manager.playlist.playMode = .shuffle
                    }
                }
            }

            // 窗口菜单 - 保留但暂时不实现歌词窗口
            CommandMenu("窗口") {
                Button("播放列表") {
                    // 注意：这个功能需要窗口级别的状态管理
                    // 暂时通过快捷键实现
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])

                Button("均衡器") {
                    // 注意：这个功能需要窗口级别的状态管理
                    // 暂时通过快捷键实现
                }
                .keyboardShortcut("e", modifiers: .command)
            }
        }
    }

    /// 打开文件选择器
    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            .audio,
            .mp3,
            .mpeg4Audio
        ]
        panel.message = "选择音乐文件"

        if panel.runModal() == .OK {
            Task {
                await manager.importTracks(from: panel.urls)
            }
        }
    }
}
