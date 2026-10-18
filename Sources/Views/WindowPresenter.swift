//
//  WindowPresenter.swift
//  TTPlayer for macOS
//
//  歌词窗口和均衡器窗口只保留一份，关掉后可以再打开
//

import SwiftUI

@MainActor
final class PanelController: ObservableObject {
    @Published var playlistDocked = true
    @Published var lyricsOpen = false
    @Published var equalizerOpen = false
    @Published var pinned = false

    private var lyricsWindow: NSWindow?
    private var equalizerWindow: NSWindow?
    private var lyricsDelegate: WindowCloseProxy?
    private var equalizerDelegate: WindowCloseProxy?

    func toggleLyrics(syncEngine: LyricSyncEngine, manager: PlaybackManager) {
        if presentExisting(lyricsWindow, flag: \.lyricsOpen) { return }

        let window = makeWindow(
            root: ClassicLyricWindow(syncEngine: syncEngine).environmentObject(manager),
            title: "歌词",
            size: NSSize(width: 420, height: 520),
            resizable: true
        )
        lyricsDelegate = WindowCloseProxy { [weak self] in
            self?.lyricsOpen = false
        }
        window.delegate = lyricsDelegate
        lyricsWindow = window
        lyricsOpen = true
        window.makeKeyAndOrderFront(nil)
    }

    func toggleEqualizer(equalizer: AudioEqualizer) {
        if presentExisting(equalizerWindow, flag: \.equalizerOpen) { return }

        let window = makeWindow(
            root: ClassicEqualizerWindow(equalizer: equalizer),
            title: "均衡器",
            size: NSSize(width: 520, height: 280),
            resizable: false
        )
        equalizerDelegate = WindowCloseProxy { [weak self] in
            self?.equalizerOpen = false
        }
        window.delegate = equalizerDelegate
        equalizerWindow = window
        equalizerOpen = true
        window.makeKeyAndOrderFront(nil)
    }

    func setPinned(_ pinned: Bool) {
        self.pinned = pinned
        applyPin(to: mainWindow)
    }

    func applyPin(to window: NSWindow?) {
        window?.level = pinned ? .floating : .normal
    }

    private func presentExisting(_ window: NSWindow?, flag: ReferenceWritableKeyPath<PanelController, Bool>) -> Bool {
        guard let window else { return false }
        if window.isVisible {
            window.orderOut(nil)
            self[keyPath: flag] = false
            return true
        }
        window.makeKeyAndOrderFront(nil)
        self[keyPath: flag] = true
        return true
    }

    private func makeWindow<Content: View>(
        root: Content,
        title: String,
        size: NSSize,
        resizable: Bool
    ) -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: root))
        window.title = title
        window.setContentSize(size)
        window.styleMask = resizable
            ? [.titled, .closable, .miniaturizable, .resizable]
            : [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.center()
        return window
    }

    private var mainWindow: NSWindow? {
        NSApp.windows.first { $0.title == "千千静听" }
    }
}

final class WindowCloseProxy: NSObject, NSWindowDelegate {
    var onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}

/// 隐藏系统红绿灯，让主窗口用自绘标题栏，并在收起列表时把高度收回播放器本身
struct PlayerWindowHost: NSViewRepresentable {
    var playlistDocked: Bool
    var pinned: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            if !context.coordinator.didConfigure {
                context.coordinator.didConfigure = true
                window.title = "千千静听"
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.styleMask.insert(.fullSizeContentView)
                window.isMovableByWindowBackground = true
                window.backgroundColor = NSColor(srgbRed: 0x1B / 255, green: 0x24 / 255, blue: 0x2C / 255, alpha: 1)
                window.standardWindowButton(.closeButton)?.isHidden = true
                window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                window.standardWindowButton(.zoomButton)?.isHidden = true
            }

            window.level = self.pinned ? .floating : .normal

            let chrome = PlayerMetrics.chrome
            let dockChanged = context.coordinator.playlistDocked != self.playlistDocked
            context.coordinator.playlistDocked = self.playlistDocked

            if self.playlistDocked {
                window.minSize = NSSize(width: 460, height: chrome + 160)
                window.maxSize = NSSize(width: 1400, height: 2400)
                if dockChanged, window.frame.height < chrome + 180 {
                    self.resize(window, height: chrome + 300)
                }
            } else {
                window.minSize = NSSize(width: 460, height: chrome)
                window.maxSize = NSSize(width: 1400, height: chrome)
                if dockChanged || abs(window.frame.height - chrome) > 1 {
                    self.resize(window, height: chrome)
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func resize(_ window: NSWindow, height: CGFloat) {
        var frame = window.frame
        frame.origin.y += frame.size.height - height
        frame.size.height = height
        window.setFrame(frame, display: true, animate: false)
    }

    final class Coordinator {
        var didConfigure = false
        var playlistDocked: Bool?
    }
}
