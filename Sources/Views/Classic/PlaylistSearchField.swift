//
//  PlaylistSearchField.swift
//  TTPlayer for macOS
//
//  列表搜索。不用 SwiftUI TextField：系统文字层会把点击当成拖窗口。
//

import AppKit
import SwiftUI

struct PlaylistSearchField: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> SearchFieldHost {
        let host = SearchFieldHost()
        host.field.placeholderString = "搜索歌名或专辑"
        host.field.delegate = context.coordinator
        context.coordinator.host = host
        return host
    }

    func updateNSView(_ host: SearchFieldHost, context: Context) {
        context.coordinator.text = $text
        context.coordinator.host = host
        let editing = host.field.currentEditor() != nil
        if !editing, host.field.stringValue != text {
            host.field.stringValue = text
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        weak var host: SearchFieldHost?

        init(text: Binding<String>) {
            self.text = text
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }
    }
}

/// 自己吃掉点击，绝不把按下交给「拖动窗口背景」。
final class SearchFieldHost: NSView {
    let field = NSTextField(string: "")

    override var mouseDownCanMoveWindow: Bool { false }
    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        field.isEditable = true
        field.isSelectable = true
        field.isBordered = true
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.drawsBackground = true
        field.font = .systemFont(ofSize: 12)
        field.focusRingType = .exterior
        field.cell?.sendsActionOnEndEditing = false
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addSubview(field)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        field.frame = bounds
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        return bounds.contains(local) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        NSApp.activate(ignoringOtherApps: true)
        guard let window else { return }
        window.makeKeyAndOrderFront(nil)
        window.isMovableByWindowBackground = false
        if window.firstResponder !== field && window.firstResponder !== field.currentEditor() {
            window.makeFirstResponder(field)
        }
        field.mouseDown(with: event)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .iBeam)
    }
}
