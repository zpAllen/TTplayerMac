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
    @Published var bindings: [HotkeyBinding] = HotkeyStore.load()

    private var actions: [String: () -> Void] = [:]
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

    /// 记下动作，并按已保存的按键注册。再次调用会先卸掉旧热键。
    func registerDefaultHotkeys(
        onPlayPause: @escaping () -> Void,
        onNext: @escaping () -> Void,
        onPrevious: @escaping () -> Void,
        onVolumeUp: @escaping () -> Void,
        onVolumeDown: @escaping () -> Void,
        onShowLyrics: @escaping () -> Void
    ) {
        actions = [
            "play": onPlayPause,
            "next": onNext,
            "previous": onPrevious,
            "volumeUp": onVolumeUp,
            "volumeDown": onVolumeDown,
            "lyrics": onShowLyrics
        ]
        applyBindings()
        print("✅ 全局快捷键已注册")
        for binding in bindings {
            print("   \(label(for: binding)): \(HotkeyBinding.title(for: binding.action))")
        }
    }

    func applyBindings() {
        unregisterAll()
        for binding in bindings {
            guard binding.keyCode != UInt32.max, let action = actions[binding.action] else { continue }
            register(key: binding.keyCode, modifiers: binding.modifiers, action: action)
        }
        isEnabled = !actions.isEmpty
    }

    func updateBinding(action: String, keyCode: UInt32, modifiers: UInt32) {
        for index in bindings.indices
        where bindings[index].action != action
            && bindings[index].keyCode == keyCode
            && bindings[index].modifiers == modifiers {
            bindings[index].keyCode = UInt32.max
            bindings[index].modifiers = 0
        }
        if let index = bindings.firstIndex(where: { $0.action == action }) {
            bindings[index].keyCode = keyCode
            bindings[index].modifiers = modifiers
        }
        HotkeyStore.save(bindings)
        applyBindings()
    }

    func label(for binding: HotkeyBinding) -> String {
        HotkeyBinding.label(keyCode: binding.keyCode, modifiers: binding.modifiers)
    }
}

struct HotkeyBinding: Codable, Identifiable, Equatable {
    var action: String
    var keyCode: UInt32
    var modifiers: UInt32

    var id: String { action }

    static func title(for action: String) -> String {
        switch action {
        case "play": return "播放/暂停"
        case "next": return "下一首"
        case "previous": return "上一首"
        case "volumeUp": return "音量增加"
        case "volumeDown": return "音量减小"
        case "lyrics": return "桌面歌词"
        default: return action
        }
    }

    static func label(keyCode: UInt32, modifiers: UInt32) -> String {
        if keyCode == UInt32.max { return "未设置" }
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        parts.append(keyName(keyCode))
        return parts.joined()
    }

    private static func keyName(_ keyCode: UInt32) -> String {
        let names: [UInt32: String] = [
            UInt32(kVK_ANSI_A): "A", UInt32(kVK_ANSI_B): "B", UInt32(kVK_ANSI_C): "C",
            UInt32(kVK_ANSI_D): "D", UInt32(kVK_ANSI_E): "E", UInt32(kVK_ANSI_F): "F",
            UInt32(kVK_ANSI_G): "G", UInt32(kVK_ANSI_H): "H", UInt32(kVK_ANSI_I): "I",
            UInt32(kVK_ANSI_J): "J", UInt32(kVK_ANSI_K): "K", UInt32(kVK_ANSI_L): "L",
            UInt32(kVK_ANSI_M): "M", UInt32(kVK_ANSI_N): "N", UInt32(kVK_ANSI_O): "O",
            UInt32(kVK_ANSI_P): "P", UInt32(kVK_ANSI_Q): "Q", UInt32(kVK_ANSI_R): "R",
            UInt32(kVK_ANSI_S): "S", UInt32(kVK_ANSI_T): "T", UInt32(kVK_ANSI_U): "U",
            UInt32(kVK_ANSI_V): "V", UInt32(kVK_ANSI_W): "W", UInt32(kVK_ANSI_X): "X",
            UInt32(kVK_ANSI_Y): "Y", UInt32(kVK_ANSI_Z): "Z",
            UInt32(kVK_ANSI_0): "0", UInt32(kVK_ANSI_1): "1", UInt32(kVK_ANSI_2): "2",
            UInt32(kVK_ANSI_3): "3", UInt32(kVK_ANSI_4): "4", UInt32(kVK_ANSI_5): "5",
            UInt32(kVK_ANSI_6): "6", UInt32(kVK_ANSI_7): "7", UInt32(kVK_ANSI_8): "8",
            UInt32(kVK_ANSI_9): "9",
            UInt32(kVK_LeftArrow): "←", UInt32(kVK_RightArrow): "→",
            UInt32(kVK_UpArrow): "↑", UInt32(kVK_DownArrow): "↓",
            UInt32(kVK_Space): "空格", UInt32(kVK_Return): "回车"
        ]
        return names[keyCode] ?? "键\(keyCode)"
    }
}

enum HotkeyStore {
    private static let defaultsKey = "hotkeys.bindings"

    static func load() -> [HotkeyBinding] {
        let fallback = defaults()
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([HotkeyBinding].self, from: data) else {
            return fallback
        }
        var merged = fallback
        for binding in decoded {
            if let index = merged.firstIndex(where: { $0.action == binding.action }) {
                merged[index] = binding
            }
        }
        return merged
    }

    static func save(_ bindings: [HotkeyBinding]) {
        if let data = try? JSONEncoder().encode(bindings) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    static func defaults() -> [HotkeyBinding] {
        let modifiers = UInt32(cmdKey | optionKey)
        return [
            HotkeyBinding(action: "play", keyCode: UInt32(kVK_ANSI_P), modifiers: modifiers),
            HotkeyBinding(action: "next", keyCode: UInt32(kVK_RightArrow), modifiers: modifiers),
            HotkeyBinding(action: "previous", keyCode: UInt32(kVK_LeftArrow), modifiers: modifiers),
            HotkeyBinding(action: "volumeUp", keyCode: UInt32(kVK_UpArrow), modifiers: modifiers),
            HotkeyBinding(action: "volumeDown", keyCode: UInt32(kVK_DownArrow), modifiers: modifiers),
            HotkeyBinding(action: "lyrics", keyCode: UInt32(kVK_ANSI_L), modifiers: modifiers)
        ]
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
