//
//  GlobalHotkeyManager.swift
//  TTPlayer for macOS
//
//  全局快捷键管理器（Carbon Event）
//

import Foundation
import Carbon
import Combine
import AppKit

/// 全局快捷键管理器
class GlobalHotkeyManager: ObservableObject {
    // MARK: - Properties

    @Published var isEnabled: Bool = false

    private var hotkeys: [UInt32: () -> Void] = [:]
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var eventHandler: EventHandlerRef?
    private var nextHotkeyID: UInt32 = 1

    // MARK: - Initialization

    init() {
        setupEventHandler()
    }

    deinit {
        unregisterAll()
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
    }

    // MARK: - Setup

    private func setupEventHandler() {
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let callback: EventHandlerUPP = { (nextHandler, event, userData) -> OSStatus in
            var hotkeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotkeyID
            )

            guard status == noErr else { return status }

            // 获取管理器实例
            let manager = Unmanaged<GlobalHotkeyManager>
                .fromOpaque(userData!)
                .takeUnretainedValue()

            // 触发回调
            manager.hotkeys[hotkeyID.id]?()

            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    // MARK: - Registration

    /// 注册全局快捷键
    @discardableResult
    func register(
        key: UInt32,
        modifiers: UInt32,
        action: @escaping () -> Void
    ) -> Bool {
        let hotkeyID = EventHotKeyID(
            signature: OSType(0x5454504C),  // 'TTPL'
            id: nextHotkeyID
        )
        nextHotkeyID += 1

        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            key,
            modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr, let ref = hotKeyRef else {
            print("注册热键失败: \(status)")
            return false
        }

        hotKeyRefs.append(ref)
        hotkeys[hotkeyID.id] = action

        return true
    }

    /// 注销所有快捷键
    func unregisterAll() {
        for ref in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        hotkeys.removeAll()
    }

    // MARK: - Default Hotkeys

    /// 注册默认快捷键
    func registerDefaultHotkeys(
        onPlayPause: @escaping () -> Void,
        onNext: @escaping () -> Void,
        onPrevious: @escaping () -> Void,
        onVolumeUp: @escaping () -> Void,
        onVolumeDown: @escaping () -> Void,
        onShowLyrics: @escaping () -> Void
    ) {
        // Cmd+Option+P: 播放/暂停
        register(
            key: UInt32(kVK_ANSI_P),
            modifiers: UInt32(cmdKey | optionKey),
            action: onPlayPause
        )

        // Cmd+Option+Right: 下一曲
        register(
            key: UInt32(kVK_RightArrow),
            modifiers: UInt32(cmdKey | optionKey),
            action: onNext
        )

        // Cmd+Option+Left: 上一曲
        register(
            key: UInt32(kVK_LeftArrow),
            modifiers: UInt32(cmdKey | optionKey),
            action: onPrevious
        )

        // Cmd+Option+Up: 音量增加
        register(
            key: UInt32(kVK_UpArrow),
            modifiers: UInt32(cmdKey | optionKey),
            action: onVolumeUp
        )

        // Cmd+Option+Down: 音量减小
        register(
            key: UInt32(kVK_DownArrow),
            modifiers: UInt32(cmdKey | optionKey),
            action: onVolumeDown
        )

        // Cmd+Option+L: 显示/隐藏歌词
        register(
            key: UInt32(kVK_ANSI_L),
            modifiers: UInt32(cmdKey | optionKey),
            action: onShowLyrics
        )

        isEnabled = true
        print("✅ 全局快捷键已注册")
        print("   Cmd+Option+P: 播放/暂停")
        print("   Cmd+Option+→: 下一曲")
        print("   Cmd+Option+←: 上一曲")
        print("   Cmd+Option+↑: 音量+")
        print("   Cmd+Option+↓: 音量-")
        print("   Cmd+Option+L: 歌词")
    }
}

// MARK: - Accessibility Check

extension GlobalHotkeyManager {
    /// 检查辅助功能权限
    static func checkAccessibility() -> Bool {
        let options: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true
        ]
        return AXIsProcessTrustedWithOptions(options)
    }

    /// 请求辅助功能权限
    static func requestAccessibilityPermission() {
        let alert = NSAlert()
        alert.messageText = "需要辅助功能权限"
        alert.informativeText = """
        TTPlayer 需要辅助功能权限才能使用全局快捷键。

        请在以下界面中勾选 TTPlayer：
        系统偏好设置 > 安全性与隐私 > 隐私 > 辅助功能
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "打开系统偏好设置")
        alert.addButton(withTitle: "稍后")

        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
