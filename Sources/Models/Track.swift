//
//  Track.swift
//  TTPlayer for macOS
//
//  音频曲目数据模型
//

import Foundation
import AVFoundation

/// 音频曲目
struct Track: Identifiable, Codable, Equatable {
    let id: UUID
    let url: URL
    var title: String
    var artist: String?
    var album: String?
    var duration: TimeInterval
    var artworkData: Data?

    /// 初始化曲目
    init(
        id: UUID = UUID(),
        url: URL,
        title: String,
        artist: String? = nil,
        album: String? = nil,
        duration: TimeInterval = 0,
        artworkData: Data? = nil
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.artworkData = artworkData
    }

    /// 从文件 URL 创建曲目
    static func from(url: URL) async -> Track? {
        let asset = AVAsset(url: url)

        // 获取元数据
        guard let metadata = try? await asset.load(.commonMetadata) else {
            return Track(
                url: url,
                title: url.deletingPathExtension().lastPathComponent
            )
        }

        var title: String?
        var artist: String?
        var album: String?
        var artworkData: Data?

        for item in metadata {
            guard let key = item.commonKey?.rawValue,
                  let value = try? await item.load(.value) else {
                continue
            }

            switch key {
            case "title":
                title = value as? String
            case "artist":
                artist = value as? String
            case "albumName":
                album = value as? String
            case "artwork":
                if let data = value as? Data {
                    artworkData = data
                }
            default:
                break
            }
        }

        if artworkData == nil {
            artworkData = await Self.embeddedArtwork(from: asset)
        }

        // 获取时长
        let duration = try? await asset.load(.duration).seconds

        return Track(
            url: url,
            title: title ?? url.deletingPathExtension().lastPathComponent,
            artist: artist,
            album: album,
            duration: duration ?? 0,
            artworkData: artworkData
        )
    }

    /// 从 ID3 APIC 等标签读取封面。commonMetadata 没有图时用这条路径。
    private static func embeddedArtwork(from asset: AVAsset) async -> Data? {
        guard let formats = try? await asset.load(.availableMetadataFormats) else { return nil }

        for format in formats {
            guard let items = try? await asset.loadMetadata(for: format) else { continue }
            for item in items {
                let identifier = item.identifier?.rawValue.lowercased() ?? ""
                let key = ((item.key as? String) ?? "").lowercased()
                let isArtwork = item.commonKey?.rawValue == "artwork"
                    || identifier.contains("apic")
                    || identifier.contains("artwork")
                    || key == "apic"
                guard isArtwork else { continue }
                if let data = try? await item.load(.dataValue), !data.isEmpty {
                    return data
                }
            }
        }

        return nil
    }

    /// 显示名称（用于列表显示）
    var displayName: String {
        if let artist = artist {
            return "\(artist) - \(title)"
        }
        return title
    }

    /// 格式化时长
    var formattedDuration: String {
        formatTime(duration)
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, url, title, artist, album, duration, artworkData
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        url = try container.decode(URL.self, forKey: .url)
        title = try container.decode(String.self, forKey: .title)
        artist = try container.decodeIfPresent(String.self, forKey: .artist)
        album = try container.decodeIfPresent(String.self, forKey: .album)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        artworkData = try container.decodeIfPresent(Data.self, forKey: .artworkData)
    }
}

// MARK: - Utilities

/// 格式化时间（秒 -> mm:ss）
func formatTime(_ seconds: TimeInterval) -> String {
    guard !seconds.isNaN && !seconds.isInfinite else {
        return "00:00"
    }

    let totalSeconds = Int(seconds)
    let minutes = totalSeconds / 60
    let secs = totalSeconds % 60
    return String(format: "%02d:%02d", minutes, secs)
}
