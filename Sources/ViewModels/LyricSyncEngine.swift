//
//  LyricSyncEngine.swift
//  TTPlayer for macOS
//
//  歌词同步引擎
//

import Foundation
import Combine

/// 歌词同步引擎
class LyricSyncEngine: ObservableObject {
    // MARK: - Published Properties

    @Published var currentLine: LRCLine?
    @Published var currentIndex: Int?
    /// 当前行播放进度 0.0 ~ 1.0。刻意不发布：进度每秒变十次，
    /// 发布出去会让整个主窗口跟着重算。桌面歌词在每次时间刷新时主动读它。
    private(set) var progress: Double = 0.0
    /// 用户额外提前或延后，单位秒。和文件里的 [offset:] 分开，避免存 LRC 时加两次。
    @Published var userOffset: TimeInterval = UserDefaults.standard.double(forKey: "lyrics.userOffset")

    // MARK: - Private Properties

    private var document: LyricDocument?
    private var lastTime: TimeInterval = 0
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {}

    // MARK: - Load

    /// 加载歌词文档
    func load(document: LyricDocument) {
        self.document = document
        currentLine = nil
        currentIndex = nil
        progress = 0.0
    }

    /// 加载歌词文件
    func load(url: URL) {
        let doc = LyricDocument()
        do {
            try doc.parse(url: url)
            load(document: doc)
        } catch {
            print("加载歌词失败: \(error)")
        }
    }

    /// 清空歌词
    func clear() {
        document = nil
        currentLine = nil
        currentIndex = nil
        progress = 0.0
    }

    // MARK: - Update

    /// 提前为负，延后为正，限制在 ±10 秒。改完立刻按当前进度重对齐。
    func setUserOffset(_ value: TimeInterval) {
        let clamped = min(10, max(-10, value))
        userOffset = clamped
        UserDefaults.standard.set(clamped, forKey: "lyrics.userOffset")
        update(time: lastTime)
    }

    /// 把当前歌词存成听到的时间轴。
    func exportedLRC() -> String? {
        guard let document, !document.lines.isEmpty else { return nil }
        return document.exportedLRC(shiftingBy: userOffset)
    }

    /// 更新当前时间（秒）
    func update(time: TimeInterval) {
        lastTime = time
        guard let document = document else { return }

        let adjusted = time + userOffset
        let newLine = document.currentLine(at: adjusted)
        let newIndex = document.currentLineIndex(at: adjusted)

        // 更新当前行
        if newLine?.id != currentLine?.id {
            currentLine = newLine
            currentIndex = newIndex
        }

        // 计算行内进度
        if let line = currentLine {
            // 查找下一行的时间
            let nextTime: TimeInterval
            if let index = newIndex, index + 1 < document.lines.count {
                nextTime = document.lines[index + 1].timestamp
            } else {
                nextTime = adjusted + 5.0
            }

            let duration = nextTime - line.timestamp
            let elapsed = adjusted - line.timestamp

            progress = duration > 0 ? min(1.0, max(0.0, elapsed / duration)) : 0.0
        } else {
            progress = 0.0
        }
    }

    // MARK: - Query

    /// 获取下一行歌词
    var nextLine: LRCLine? {
        guard let document = document,
              let index = currentIndex,
              index + 1 < document.lines.count else {
            return nil
        }
        return document.lines[index + 1]
    }

    /// 获取上一行歌词
    var previousLine: LRCLine? {
        guard let document = document,
              let index = currentIndex,
              index > 0 else {
            return nil
        }
        return document.lines[index - 1]
    }

    /// 获取所有歌词行
    var allLines: [LRCLine] {
        return document?.lines ?? []
    }

    /// 获取元数据
    var metadata: LRCMetadata? {
        return document?.metadata
    }
}

// MARK: - Auto Sync

extension LyricSyncEngine {
    /// 连接到音频播放器（自动同步）
    func connect(to player: AudioPlayer) {
        player.$currentTime
            .sink { [weak self] time in
                self?.update(time: time)
            }
            .store(in: &cancellables)
    }

    /// 连接到增强型播放器
    func connect(to player: EnhancedAudioPlayer) {
        player.$currentTime
            .sink { [weak self] time in
                self?.update(time: time)
            }
            .store(in: &cancellables)
    }
}
