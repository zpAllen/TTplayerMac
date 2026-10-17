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

    /// 下一曲
    @discardableResult
    func next() -> Track? {
        switch playMode {
        case .sequential:
            if currentIndex < tracks.count - 1 {
                currentIndex += 1
            } else {
                return nil  // 列表结束
            }

        case .shuffle:
            if shuffleIndices.isEmpty {
                generateShuffleIndices()
            }
            if let currentShuffleIndex = shuffleIndices.firstIndex(of: currentIndex) {
                let nextShuffleIndex = (currentShuffleIndex + 1) % shuffleIndices.count
                currentIndex = shuffleIndices[nextShuffleIndex]
            }

        case .repeatOne:
            // 保持当前索引不变
            break

        case .repeatAll:
            currentIndex = (currentIndex + 1) % tracks.count
        }

        return currentTrack
    }

    /// 上一曲
    @discardableResult
    func previous() -> Track? {
        switch playMode {
        case .sequential:
            if currentIndex > 0 {
                currentIndex -= 1
            }

        case .shuffle:
            if shuffleIndices.isEmpty {
                generateShuffleIndices()
            }
            if let currentShuffleIndex = shuffleIndices.firstIndex(of: currentIndex) {
                let prevShuffleIndex = (currentShuffleIndex - 1 + shuffleIndices.count) % shuffleIndices.count
                currentIndex = shuffleIndices[prevShuffleIndex]
            }

        case .repeatOne:
            // 保持当前索引不变
            break

        case .repeatAll:
            currentIndex = (currentIndex - 1 + tracks.count) % tracks.count
        }

        return currentTrack
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
