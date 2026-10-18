//
//  Playlist.swift
//  TTPlayer for macOS
//
//  播放列表模型
//

import Foundation

/// 播放模式
enum PlayMode: String, Codable, CaseIterable {
    case sequential = "顺序播放"
    case shuffle = "随机播放"
    case repeatOne = "单曲循环"
    case repeatAll = "列表循环"

    var icon: String {
        switch self {
        case .sequential: return "arrow.right"
        case .shuffle: return "shuffle"
        case .repeatOne: return "repeat.1"
        case .repeatAll: return "repeat"
        }
    }
}

/// 播放列表
class Playlist: ObservableObject, Codable {
    @Published var name: String
    @Published var tracks: [Track] = []
    @Published var currentIndex: Int = 0
    @Published var playMode: PlayMode = .sequential

    private var shuffleIndices: [Int] = []

    init(name: String = "默认列表") {
        self.name = name
    }

    // MARK: - 播放控制

    /// 当前曲目
    var currentTrack: Track? {
        guard currentIndex >= 0 && currentIndex < tracks.count else {
            return nil
        }
        return tracks[currentIndex]
    }

    /// 手动上一首 / 下一首：沿列表左右移动，不受单曲循环影响
    @discardableResult
    func skip(by step: Int) -> Track? {
        guard !tracks.isEmpty else { return nil }
        let index = currentIndex + step
        guard index >= 0 && index < tracks.count else { return nil }
        currentIndex = index
        return currentTrack
    }

    /// 一首播完后的下一首。单曲循环留在当前首，顺序播放到末尾则停止。
    @discardableResult
    func trackAfterFinishing() -> Track? {
        guard !tracks.isEmpty else { return nil }

        switch playMode {
        case .repeatOne:
            return currentTrack

        case .sequential:
            guard currentIndex < tracks.count - 1 else { return nil }
            currentIndex += 1

        case .repeatAll:
            currentIndex = (currentIndex + 1) % tracks.count

        case .shuffle:
            if shuffleIndices.isEmpty {
                generateShuffleIndices()
            }
            if let currentShuffleIndex = shuffleIndices.firstIndex(of: currentIndex) {
                let nextShuffleIndex = (currentShuffleIndex + 1) % shuffleIndices.count
                currentIndex = shuffleIndices[nextShuffleIndex]
            }
        }

        return currentTrack
    }

    /// 下一曲（手动）
    @discardableResult
    func next() -> Track? {
        skip(by: 1)
    }

    /// 上一曲（手动）
    @discardableResult
    func previous() -> Track? {
        skip(by: -1)
    }

    /// 跳转到指定曲目
    func jumpTo(index: Int) {
        guard index >= 0 && index < tracks.count else { return }
        currentIndex = index
    }

    /// 切换播放模式
    func cyclePlayMode() {
        let modes = PlayMode.allCases
        if let currentModeIndex = modes.firstIndex(of: playMode) {
            let nextIndex = (currentModeIndex + 1) % modes.count
            playMode = modes[nextIndex]
        }
    }

    // MARK: - 列表管理

    /// 添加曲目
    func add(track: Track) {
        tracks.append(track)
        if playMode == .shuffle {
            generateShuffleIndices()
        }
    }

    /// 添加多个曲目
    func add(tracks: [Track]) {
        self.tracks.append(contentsOf: tracks)
        if playMode == .shuffle {
            generateShuffleIndices()
        }
    }

    /// 按当前曲目身份排序，避免排序后 currentIndex 还指着旧位置
    func sort(by areInIncreasingOrder: (Track, Track) -> Bool) {
        let currentId = currentTrack?.id
        tracks.sort(by: areInIncreasingOrder)
        if let currentId, let newIndex = tracks.firstIndex(where: { $0.id == currentId }) {
            currentIndex = newIndex
        }
    }

    /// 移除选中曲目
    func remove(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        let currentId = currentTrack?.id
        tracks.removeAll { ids.contains($0.id) }

        if tracks.isEmpty {
            currentIndex = 0
        } else if let currentId, let newIndex = tracks.firstIndex(where: { $0.id == currentId }) {
            currentIndex = newIndex
        } else {
            currentIndex = min(currentIndex, tracks.count - 1)
        }

        if playMode == .shuffle {
            generateShuffleIndices()
        }
    }

    /// 移除曲目
    func remove(at index: Int) {
        guard index >= 0 && index < tracks.count else { return }
        tracks.remove(at: index)

        if currentIndex >= tracks.count {
            currentIndex = max(0, tracks.count - 1)
        }

        if playMode == .shuffle {
            generateShuffleIndices()
        }
    }

    /// 清空列表
    func clear() {
        tracks.removeAll()
        currentIndex = 0
        shuffleIndices.removeAll()
    }

    // MARK: - 私有方法

    /// 生成随机播放索引
    private func generateShuffleIndices() {
        shuffleIndices = Array(0..<tracks.count).shuffled()
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case name, tracks, currentIndex, playMode
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        tracks = try container.decode([Track].self, forKey: .tracks)
        currentIndex = try container.decode(Int.self, forKey: .currentIndex)
        playMode = try container.decode(PlayMode.self, forKey: .playMode)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(tracks, forKey: .tracks)
        try container.encode(currentIndex, forKey: .currentIndex)
        try container.encode(playMode, forKey: .playMode)
    }
}
