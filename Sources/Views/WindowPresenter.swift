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
    @Published var lyricsDocked = false
    @Published var equalizerDocked = false
    @Published var lyricsOpen = false
    @Published var equalizerOpen = false
    @Published var hotkeysOpen = false
    @Published var pinned = false

    private var lyricsWindow: NSWindow?
    private var equalizerWindow: NSWindow?
    private var hotkeyWindow: NSWindow?
    private var lyricsDelegate: WindowCloseProxy?
    private var equalizerDelegate: WindowCloseProxy?
    private var hotkeyDelegate: WindowCloseProxy?

    /// 列表、歌词、均衡器下面只留一个。再点当前这个就收起。
    func togglePlaylist() {
        if playlistDocked && !lyricsDocked && !equalizerDocked {
            playlistDocked = false
            return
        }
        showPlaylist()
    }

    /// 和列表一样：有则收起，没有则停在播放器下面。独立窗口开着时，再点一次关掉窗口。
    func toggleLyrics(syncEngine _: LyricSyncEngine, manager _: PlaybackManager, desktopLyric _: DesktopLyricManager) {
        if lyricsDocked {
            lyricsDocked = false
            return
        }
        if lyricsWindow?.isVisible == true {
            lyricsWindow?.orderOut(nil)
            lyricsOpen = false
            return
        }
        showLyrics()
    }

    func popOutLyrics(syncEngine: LyricSyncEngine, manager: PlaybackManager, desktopLyric: DesktopLyricManager) {
        lyricsDocked = false
        if !equalizerDocked {
            playlistDocked = true
        }
        if let window = lyricsWindow {
            window.makeKeyAndOrderFront(nil)
            lyricsOpen = true
            return
        }
        let window = makeWindow(
            root: ClassicLyricWindow(syncEngine: syncEngine)
                .environmentObject(manager)
                .environmentObject(desktopLyric),
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

    func toggleEqualizer(equalizer _: AudioEqualizer) {
        if equalizerDocked {
            equalizerDocked = false
            return
        }
        if equalizerWindow?.isVisible == true {
            equalizerWindow?.orderOut(nil)
            equalizerOpen = false
            return
        }
        showEqualizer()
    }

    func popOutEqualizer(equalizer: AudioEqualizer) {
        equalizerDocked = false
        if !lyricsDocked {
            playlistDocked = true
        }
        if let window = equalizerWindow {
            window.makeKeyAndOrderFront(nil)
            equalizerOpen = true
            return
        }
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

    func toggleHotkeys(_ hotkeys: GlobalHotkeyManager) {
        if presentExisting(hotkeyWindow, flag: \.hotkeysOpen) { return }

        let window = makeWindow(
            root: HotkeySettingsView(hotkeys: hotkeys),
            title: "快捷键",
            size: NSSize(width: 400, height: 320),
            resizable: false
        )
        hotkeyDelegate = WindowCloseProxy { [weak self] in
            self?.hotkeysOpen = false
        }
        window.delegate = hotkeyDelegate
        hotkeyWindow = window
        hotkeysOpen = true
        window.makeKeyAndOrderFront(nil)
    }

    private func showPlaylist() {
        lyricsDocked = false
        equalizerDocked = false
        playlistDocked = true
    }

    private func showLyrics() {
        playlistDocked = false
        equalizerDocked = false
        lyricsDocked = true
    }

    private func showEqualizer() {
        playlistDocked = false
        lyricsDocked = false
        equalizerDocked = true
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
    var skinSize: CGSize?
    /// 停靠的歌词和均衡器占用的高度。播放器按这个高度长高或缩短。
    var dockedExtra: CGFloat = 0

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
                // SwiftUI 输入框内部的文字层 mouseDownCanMoveWindow 为 true。
                // 若再开背景拖动，点搜索框会变成拖窗口，光标和文字都进不去。
                // 皮肤空白处由 SkinCanvas.performDrag 拖动窗口。
                window.isMovableByWindowBackground = false
                window.backgroundColor = NSColor(srgbRed: 0x1B / 255, green: 0x24 / 255, blue: 0x2C / 255, alpha: 1)
                window.standardWindowButton(.closeButton)?.isHidden = true
                window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                window.standardWindowButton(.zoomButton)?.isHidden = true
            }

            window.level = self.pinned ? .floating : .normal
            context.coordinator.watch(window)

            let chrome = PlayerMetrics.chrome
            let dockChanged = context.coordinator.playlistDocked != self.playlistDocked
            let skinChanged = context.coordinator.skinSize != self.skinSize
            let previousExtra = context.coordinator.dockedExtra ?? self.dockedExtra
            let extraChanged = previousExtra != self.dockedExtra
            context.coordinator.playlistDocked = self.playlistDocked
            context.coordinator.skinSize = self.skinSize
            context.coordinator.dockedExtra = self.dockedExtra
            let extra = self.dockedExtra

            if let skin = self.skinSize {
                window.isOpaque = false
                window.backgroundColor = .clear
                window.contentView?.wantsLayer = true
                window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
                let showsPlaylist = self.playlistDocked
                let minimum = skin.height + (showsPlaylist ? 120 : 0) + extra
                window.minSize = NSSize(width: skin.width, height: minimum)
                window.maxSize = NSSize(width: 1200, height: showsPlaylist ? 2400 : 900)
                let scale = max(window.frame.width, skin.width) / skin.width
                let skinHeight = skin.height * scale
                var height = window.frame.height
                if skinChanged || (dockChanged && showsPlaylist && height < skinHeight + 160) {
                    height = skinHeight + (showsPlaylist ? 280 : 0)
                }
                if dockChanged && !showsPlaylist {
                    height = skinHeight
                }
                if !showsPlaylist {
                    height = skinHeight
                }
                height = max(height, showsPlaylist ? skinHeight + 120 : skinHeight)
                var width = min(max(window.frame.width, skin.width), 1200)
                // 皮肤刚加载时把窗口宽对齐到整数倍。默认窗口 480 宽、皮肤约 275 宽，
                // 1.745 倍是非整数，整张背景只能走插值会糊；对齐后走最近邻，边缘利落。
                if skinChanged, !context.coordinator.didSnapSkinWidth {
                    context.coordinator.didSnapSkinWidth = true
                    let currentScale = window.frame.width / skin.width
                    let stepped = min(4, max(1, Int(currentScale.rounded())))
                    if abs(currentScale - CGFloat(stepped)) > 0.03 {
                        width = CGFloat(stepped) * skin.width
                    }
                }
                if skinChanged || dockChanged || extraChanged || abs(window.frame.height - height) > 1 {
                    // 面板开合、皮肤加载用动画过渡；播放中的高度微调保持即时。
                    let animate = skinChanged || dockChanged || extraChanged
                    if animate { context.coordinator.suspendSnap() }
                    self.resize(window, size: NSSize(width: width, height: height), animate: animate)
                }
                return
            }

            window.isOpaque = true
            window.backgroundColor = NSColor(srgbRed: 0x1B / 255, green: 0x24 / 255, blue: 0x2C / 255, alpha: 1)

            if self.playlistDocked || extra > 0 {
                window.minSize = NSSize(width: 460, height: chrome + (self.playlistDocked ? 160 : 0) + extra)
                window.maxSize = NSSize(width: 1400, height: 2400)
                if skinChanged {
                    self.resize(window, height: chrome + (self.playlistDocked ? 300 : 0) + extra, animate: true)
                } else if extraChanged {
                    self.resize(window, height: max(window.frame.height + extra - previousExtra, window.minSize.height), animate: true)
                } else if dockChanged, window.frame.height < chrome + 180 + extra {
                    self.resize(window, height: chrome + 300 + extra, animate: true)
                }
            } else {
                window.minSize = NSSize(width: 460, height: chrome)
                window.maxSize = NSSize(width: 1400, height: chrome)
                if dockChanged || extraChanged || abs(window.frame.height - chrome) > 1 {
                    self.resize(window, height: chrome, animate: true)
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func resize(_ window: NSWindow, height: CGFloat, animate: Bool = false) {
        resize(window, size: NSSize(width: window.frame.width, height: height), animate: animate)
    }

    private func resize(_ window: NSWindow, size: NSSize, animate: Bool = false) {
        var frame = window.frame
        frame.origin.y += frame.size.height - size.height
        frame.size = size
        window.setFrame(frame, display: true, animate: animate)
    }

    final class Coordinator {
        var didConfigure = false
        var playlistDocked: Bool?
        var skinSize: CGSize?
        var dockedExtra: CGFloat?
        var didSnapSkinWidth = false
        private var resizeToken: NSObjectProtocol?
        private var snapping = false
        private var snapScheduled = false
        private var snapSuspended = false

        func watch(_ window: NSWindow) {
            guard resizeToken == nil else { return }
            resizeToken = NotificationCenter.default.addObserver(
                forName: NSWindow.didResizeNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.snap(window)
                }
            }
        }

        /// 窗口动画期间先别吸附，否则 snap 会立刻把动画打断成瞬移。
        func suspendSnap() {
            snapSuspended = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.snapSuspended = false
            }
        }

        /// 拉宽时皮肤变高。没有下方面板时，窗口高度跟着皮肤走，避免底下透出桌面。
        private func snap(_ window: NSWindow) {
            guard let skin = skinSize, skin.width > 1, !snapping, !snapScheduled, !snapSuspended else { return }
            let skinHeight = skin.height * window.frame.width / skin.width
            let docked = playlistDocked == true
            let target = docked ? max(window.frame.height, skinHeight + 120) : skinHeight
            guard abs(window.frame.height - target) > 1 else { return }
            snapScheduled = true
            DispatchQueue.main.async { [weak self, weak window] in
                guard let self, let window else { return }
                self.snapScheduled = false
                guard !self.snapping else { return }
                let skinHeight = skin.height * window.frame.width / skin.width
                let docked = self.playlistDocked == true
                let target = docked ? max(window.frame.height, skinHeight + 120) : skinHeight
                guard abs(window.frame.height - target) > 1 else { return }
                self.snapping = true
                var frame = window.frame
                frame.origin.y += frame.size.height - target
                frame.size.height = target
                window.setFrame(frame, display: false, animate: false)
                self.snapping = false
            }
        }
    }
}
