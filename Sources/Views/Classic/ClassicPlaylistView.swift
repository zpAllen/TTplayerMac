//
//  ClassicPlaylistView.swift
//  TTPlayer for macOS
//
//  停靠在主窗口下方的播放列表
//

import SwiftUI

struct ClassicPlaylistView: View {
    @ObservedObject var playlist: Playlist
    @Binding var currentTrack: Track?

    var onTrackSelected: ((Track) -> Void)?
    var onImport: (([URL]) -> Void)?
    var onClear: (() -> Void)?

    @State private var query = ""
    @State private var selection = Set<UUID>()

    private struct Row: Identifiable {
        let index: Int
        let track: Track
        var id: UUID { track.id }
    }

    private var rows: [Row] {
        playlist.tracks.enumerated().compactMap { offset, track in
            let visible = query.isEmpty
                || track.displayName.localizedStandardContains(query)
                || (track.album ?? "").localizedStandardContains(query)
            return visible ? Row(index: offset, track: track) : nil
        }
    }

    private var totalDuration: TimeInterval {
        playlist.tracks.reduce(0) { $0 + $1.duration }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbarView
            listView
            statusBar
        }
        .background(TTPlayerClassicColors.mainBackground)
    }

    private var toolbarView: some View {
        HStack(spacing: 8) {
            Menu("添加") {
                Button("添加文件...") { openFiles() }
                Button("添加文件夹...") { openFolder() }
            }
            .menuStyle(.borderlessButton)
            .font(.system(size: 11))
            .fixedSize()

            Button("删除") { deleteSelectedTracks() }
                .buttonStyle(.borderless)
                .font(.system(size: 11))

            Menu("排序") {
                Button("按名称") { playlist.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending } }
                Button("按艺术家") { playlist.sort { ($0.artist ?? "").localizedStandardCompare($1.artist ?? "") == .orderedAscending } }
                Button("按时长") { playlist.sort { $0.duration < $1.duration } }
            }
            .menuStyle(.borderlessButton)
            .font(.system(size: 11))
            .fixedSize()

            Button("清空") {
                if let onClear {
                    onClear()
                } else {
                    playlist.clear()
                }
            }
                .buttonStyle(.borderless)
                .font(.system(size: 11))

            Spacer(minLength: 8)

            TextField("搜索", text: $query)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11))
                .frame(width: 140)
        }
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(TTPlayerClassicColors.controlBackground)
    }

    private var listView: some View {
        List(rows, selection: $selection) { row in
            PlaylistRowView(
                index: row.index + 1,
                track: row.track,
                isPlaying: row.track.id == currentTrack?.id
            )
            .tag(row.track.id)
            .simultaneousGesture(TapGesture(count: 2).onEnded {
                playlist.jumpTo(index: row.index)
                onTrackSelected?(row.track)
            })
            .listRowBackground(
                row.track.id == currentTrack?.id
                    ? TTPlayerClassicColors.listSelection.opacity(0.85)
                    : Color.clear
            )
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var statusBar: some View {
        HStack {
            Text("\(playlist.tracks.count) 首")
            Spacer()
            Text(formatTime(totalDuration))
            Text("·")
            Text(playlist.playMode.rawValue)
        }
        .font(.system(size: 10, design: .monospaced))
        .foregroundColor(TTPlayerClassicColors.secondaryText)
        .padding(.horizontal, 8)
        .frame(height: 18)
        .background(TTPlayerClassicColors.secondaryBackground)
    }

    private func openFiles() {
        FileOpener.openAudioFiles { urls in
            guard !urls.isEmpty else { return }
            if let onImport {
                onImport(urls)
                return
            }
            Task {
                for url in urls {
                    if let track = await Track.from(url: url) {
                        await MainActor.run {
                            playlist.add(track: track)
                        }
                    }
                }
            }
        }
    }

    private func openFolder() {
        FileOpener.openFolder { url in
            guard let url = url else { return }
            Task {
                await importFolder(url)
            }
        }
    }

    private func importFolder(_ url: URL) async {
        let urls = Self.audioFileURLs(in: url)
        if let onImport {
            await MainActor.run {
                onImport(urls)
            }
            return
        }
        for url in urls {
            if let track = await Track.from(url: url) {
                await MainActor.run {
                    playlist.add(track: track)
                }
            }
        }
    }

    private static func audioFileURLs(in folder: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey]
        ) else { return [] }

        let extensions: Set<String> = ["mp3", "m4a", "aac", "wav", "aiff", "flac", "alac", "ogg"]
        var urls: [URL] = []
        for case let fileURL as URL in enumerator {
            guard extensions.contains(fileURL.pathExtension.lowercased()) else { continue }
            urls.append(fileURL)
        }
        return urls
    }

    private func deleteSelectedTracks() {
        if selection.isEmpty, let current = currentTrack?.id {
            playlist.remove(ids: [current])
        } else {
            playlist.remove(ids: selection)
        }
        selection.removeAll()
    }
}

struct PlaylistRowView: View {
    let index: Int
    let track: Track
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text("\(index)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(TTPlayerClassicColors.tertiaryText)
                .frame(width: 28, alignment: .trailing)

            Text(isPlaying ? "▶" : "")
                .font(.system(size: 9))
                .foregroundColor(TTPlayerClassicColors.accent)
                .frame(width: 12)

            Text(track.displayName)
                .font(.system(size: 12))
                .foregroundColor(TTPlayerClassicColors.primaryText)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(track.formattedDuration)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(TTPlayerClassicColors.secondaryText)
        }
        .contentShape(Rectangle())
    }
}
