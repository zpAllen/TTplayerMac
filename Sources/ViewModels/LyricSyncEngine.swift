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
    @Published var progress: Double = 0.0  // 当前行播放进度 0.0 ~ 1.0

    // MARK: - Private Properties

    private var document: LyricDocument?
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

    /// 更新当前时间（秒）
    func update(time: TimeInterval) {
        guard let document = document else { return }

        // 查找当前行
        let newLine = document.currentLine(at: time)
        let newIndex = document.currentLineIndex(at: time)

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
                nextTime = time + 5.0  // 默认5秒后
            }

            let duration = nextTime - line.timestamp
            let elapsed = time - line.timestamp

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
