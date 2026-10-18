//
//  HotkeySettingsView.swift
//  TTPlayer for macOS
//
//  修改全局快捷键。录制时窗口要成为第一响应者。
//

import SwiftUI
import AppKit
import Carbon

struct HotkeySettingsView: View {
    @ObservedObject var hotkeys: GlobalHotkeyManager
    @State private var recording: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("全局快捷键")
                .font(.system(size: 13, weight: .semibold))
            Text("点「修改」后按下新的组合键，需要带 Command、Option 或 Control。辅助功能未授权时，这些热键不会生效。")
                .font(.system(size: 11))
                .foregroundColor(TTPlayerClassicColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(hotkeys.bindings) { binding in
                HStack {
                    Text(HotkeyBinding.title(for: binding.action))
                        .font(.system(size: 12))
                    Spacer()
                    Text(hotkeys.label(for: binding))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(TTPlayerClassicColors.accent)
                    Button(recording == binding.action ? "请按键…" : "修改") {
                        recording = binding.action
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 11))
                }
            }

            Button("恢复默认") {
                hotkeys.bindings = HotkeyStore.defaults()
                HotkeyStore.save(hotkeys.bindings)
                hotkeys.applyBindings()
                recording = nil
            }
            .buttonStyle(.borderless)
            .font(.system(size: 11))
        }
        .padding(16)
        .frame(width: 380)
        .background(TTPlayerClassicColors.mainBackground)
        .background(KeyCaptureField(active: recording != nil) { keyCode, modifiers in
            guard let action = recording else { return }
            hotkeys.updateBinding(action: action, keyCode: keyCode, modifiers: modifiers)
            recording = nil
        } onCancel: {
            recording = nil
        })
    }
}

private struct KeyCaptureField: NSViewRepresentable {
    var active: Bool
    var onCapture: (UInt32, UInt32) -> Void
    var onCancel: () -> Void

    func makeNSView(context: Context) -> KeyCaptureView {
        let view = KeyCaptureView()
        view.onCapture = onCapture
        view.onCancel = onCancel
        return view
    }

    func updateNSView(_ view: KeyCaptureView, context: Context) {
        view.onCapture = onCapture
        view.onCancel = onCancel
        view.active = active
        if active {
            DispatchQueue.main.async {
                view.window?.makeFirstResponder(view)
            }
        }
    }
}

private final class KeyCaptureView: NSView {
    var active = false
    var onCapture: ((UInt32, UInt32) -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool { active }

    override func keyDown(with event: NSEvent) {
        guard active else { return }
        if event.keyCode == UInt16(kVK_Escape) {
            onCancel?()
            return
        }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command) || flags.contains(.option) || flags.contains(.control) else { return }
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        onCapture?(UInt32(event.keyCode), modifiers)
    }
}
