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

    static let contentSize = NSSize(width: 860, height: 120)

    private var window: DesktopLyricWindow?

    // MARK: - Window Management

    /// 显示桌面歌词
    func show() {
        if window == nil {
            let panel = DesktopLyricWindow(contentSize: Self.contentSize)
            let host = NSHostingView(rootView: DesktopLyricBar(model: self))
            host.sizingOptions = []
            panel.contentView = host
            window = panel
            placeWindow()
        } else if let frame = window?.frame, frame.width < 480 || frame.height < 80 {
            placeWindow()
        }

        window?.orderFrontRegardless()
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
    }

    /// 更新双行歌词
    func update(currentLine: String, nextLine: String, progress: Double = 0.0) {
        self.currentLine = currentLine
        self.nextLine = nextLine
        self.progress = progress
    }

    /// 放到屏幕底部居中。上次若被收成小弹框，丢掉那个尺寸。
    private func placeWindow() {
        guard let window else { return }

        let savedWidth = UserDefaults.standard.double(forKey: "desktopLyric.width")
        let savedHeight = UserDefaults.standard.double(forKey: "desktopLyric.height")
        let savedX = UserDefaults.standard.double(forKey: "desktopLyric.x")
        let savedY = UserDefaults.standard.double(forKey: "desktopLyric.y")

        if savedWidth >= 480, savedHeight >= 80 {
            window.setFrame(
                NSRect(x: savedX, y: savedY, width: savedWidth, height: savedHeight),
                display: true
            )
            return
        }

        let screen = window.screen ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = Self.contentSize
        window.setFrame(
            NSRect(
                x: visible.midX - size.width / 2,
                y: visible.minY + 72,
                width: size.width,
                height: size.height
            ),
            display: true
        )
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
        placeWindow()
    }
}

// MARK: - Settings

extension DesktopLyricManager {
    /// 加载设置
    func loadSettings() {
        isVisible = UserDefaults.standard.bool(forKey: "desktopLyric.visible")
        if UserDefaults.standard.object(forKey: "desktopLyric.karaoke") != nil {
            useKaraokeEffect = UserDefaults.standard.bool(forKey: "desktopLyric.karaoke")
        }

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
