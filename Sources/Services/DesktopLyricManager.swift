//
//  DesktopLyricManager.swift
//  TTPlayer for macOS
//
//  桌面歌词管理器
//

import Foundation
import SwiftUI
import Combine

/// 桌面歌词管理器
class DesktopLyricManager: ObservableObject {
    // MARK: - Published Properties

    @Published var isVisible: Bool = false
    @Published var currentLine: String = ""
    @Published var nextLine: String = ""
    @Published var progress: Double = 0.0
    @Published var useKaraokeEffect: Bool = true

    // MARK: - Private Properties

    private var window: DesktopLyricWindow?
    private var hostingView: NSHostingView<AnyView>?

    // MARK: - Window Management

    /// 显示桌面歌词
    func show() {
        if window == nil {
            window = DesktopLyricWindow()
            updateContent()
        }

        window?.makeKeyAndOrderFront(nil)
        window?.setDraggable(true)
        isVisible = true
    }

    /// 隐藏桌面歌词
    func hide() {
        window?.orderOut(nil)
        isVisible = false
    }

    /// 切换显示/隐藏
    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    // MARK: - Content Update

    /// 更新歌词内容
    func update(line: String, progress: Double = 0.0) {
        self.currentLine = line
        self.progress = progress
        updateContent()
    }

    /// 更新双行歌词
    func update(currentLine: String, nextLine: String, progress: Double = 0.0) {
        self.currentLine = currentLine
        self.nextLine = nextLine
        self.progress = progress
        updateContent()
    }

    private func updateContent() {
        guard let window = window else { return }

        let content: AnyView

        if useKaraokeEffect {
            content = AnyView(
                KaraokeLyricView(line: currentLine, progress: progress)
            )
        } else {
            content = AnyView(
                DesktopLyricView(line: currentLine)
            )
        }

        if hostingView == nil {
            hostingView = NSHostingView(rootView: content)
            window.contentView = hostingView
        } else {
            hostingView?.rootView = content
        }
    }

    // MARK: - Position Management

    /// 保存窗口位置
    func savePosition() {
        guard let window = window else { return }
        let frame = window.frame

        UserDefaults.standard.set(frame.origin.x, forKey: "desktopLyric.x")
        UserDefaults.standard.set(frame.origin.y, forKey: "desktopLyric.y")
        UserDefaults.standard.set(frame.size.width, forKey: "desktopLyric.width")
        UserDefaults.standard.set(frame.size.height, forKey: "desktopLyric.height")
    }

    /// 恢复窗口位置
    func restorePosition() {
        guard let window = window else { return }

        let x = UserDefaults.standard.double(forKey: "desktopLyric.x")
        let y = UserDefaults.standard.double(forKey: "desktopLyric.y")
        let width = UserDefaults.standard.double(forKey: "desktopLyric.width")
        let height = UserDefaults.standard.double(forKey: "desktopLyric.height")

        if width > 0 && height > 0 {
            window.setFrame(
                NSRect(x: x, y: y, width: width, height: height),
                display: true
            )
        } else {
            window.center()
        }
    }
}

// MARK: - Settings

extension DesktopLyricManager {
    /// 加载设置
    func loadSettings() {
        isVisible = UserDefaults.standard.bool(forKey: "desktopLyric.visible")
        useKaraokeEffect = UserDefaults.standard.bool(forKey: "desktopLyric.karaoke")

        if isVisible {
            show()
            restorePosition()
        }
    }

    /// 保存设置
    func saveSettings() {
        UserDefaults.standard.set(isVisible, forKey: "desktopLyric.visible")
        UserDefaults.standard.set(useKaraokeEffect, forKey: "desktopLyric.karaoke")
        savePosition()
    }
}
