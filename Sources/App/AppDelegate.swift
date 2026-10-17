//
//  AppDelegate.swift
//  TTPlayer for macOS
//
//  应用代理
//

import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    // 窗口引用
    var mainWindow: NSWindow?
    var lyricWindow: NSWindow?
    var playlistWindow: NSWindow?
    var equalizerWindow: NSWindow?

    // 管理器
    let hotkeyManager = GlobalHotkeyManager()
    let desktopLyricManager = DesktopLyricManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🎵 TTPlayer for macOS 启动")

        // 检查辅助功能权限
        if !GlobalHotkeyManager.checkAccessibility() {
            GlobalHotkeyManager.requestAccessibilityPermission()
        }

        // 设置窗口样式
        setupWindows()

        // 加载设置
        desktopLyricManager.loadSettings()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 保存设置
        desktopLyricManager.saveSettings()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false  // 关闭窗口不退出程序
    }

    private func setupWindows() {
        // 设置主窗口样式
        if let window = NSApp.windows.first {
            mainWindow = window

            // 固定大小
            window.styleMask.remove(.resizable)

            // 深色外观
            window.appearance = NSAppearance(named: .darkAqua)

            // 隐藏标题栏
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden

            // 可通过背景拖动
            window.isMovableByWindowBackground = true
        }
    }

    // MARK: - Window Management

    func showLyricWindow() {
        if lyricWindow == nil {
            lyricWindow = NSWindow(
                contentRect: NSRect(x: 100, y: 100, width: 400, height: 500),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            lyricWindow?.title = "歌词"
            lyricWindow?.appearance = NSAppearance(named: .darkAqua)
        }

        lyricWindow?.makeKeyAndOrderFront(nil)
    }

    func showPlaylistWindow() {
        if playlistWindow == nil {
            playlistWindow = NSWindow(
                contentRect: NSRect(x: 100, y: 100, width: 400, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            playlistWindow?.title = "播放列表"
            playlistWindow?.appearance = NSAppearance(named: .darkAqua)
        }

        playlistWindow?.makeKeyAndOrderFront(nil)
    }

    func showEqualizerWindow() {
        if equalizerWindow == nil {
            equalizerWindow = NSWindow(
                contentRect: NSRect(x: 100, y: 100, width: 450, height: 200),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            equalizerWindow?.title = "均衡器"
            equalizerWindow?.appearance = NSAppearance(named: .darkAqua)
        }

        equalizerWindow?.makeKeyAndOrderFront(nil)
    }
}
