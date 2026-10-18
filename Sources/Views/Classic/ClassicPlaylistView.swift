//
//  ClassicPlaylistView.swift
//  TTPlayer for macOS
//
//  停靠在主窗口下方的播放列表
//

import SwiftUI

struct ClassicPlaylistView: View {
    @ObservedObject var playlist: Playlist
    var lists: [Playlist]
    var currentTrackID: UUID?

    var onTrackSelected: ((Track) -> Void)?
    var onImport: (([URL]) -> Void)?
    var onClear: (() -> Void)?
    var onSelectList: (UUID) -> Void
    var onCreateList: (String) -> Void
    var onDeleteList: (UUID) -> Void
    var onImportList: (URL) -> Void
    var onExportList: (URL) -> Void
    var onCyclePlayMode: (() -> Void)?

    @State private var query = ""
    @State private var selection = Set<UUID>()
    @State private var namingList = false
    @State private var newListName = ""

    private struct Row: Identifiable {
        let index: Int
        let track: Track
        var id: UUID { track.id }
    }

    private var rows: [Row] {
        playlist.tracks.enumerated().compactMap { offset, track in
            let visible = query.isEmpty || Self.matches(track, query: query)
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
        VStack(spacing: 0) {
            HStack(spacing: 2) {
                toolbarMenu("添加") {
                    Button("添加文件...") { openFiles() }
                    Button("添加文件夹...") { openFolder() }
                }

                toolbarMenu("排序") {
                    Button("按名称") { playlist.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending } }
                    Button("按艺术家") { playlist.sort { ($0.artist ?? "").localizedStandardCompare($1.artist ?? "") == .orderedAscending } }
                    Button("按时长") { playlist.sort { $0.duration < $1.duration } }
                }

                toolbarMenu(playlist.name, maxWidth: 120) {
                    ForEach(lists) { list in
                        Button(list.name) {
                            onSelectList(list.id)
                        }
                    }
                    Divider()
                    Button("新建列表...") { namingList = true }
                    Button("删除当前列表") {
                        onDeleteList(playlist.id)
                    }
                    .disabled(lists.count < 2)
                    Button("删除选中") { deleteSelectedTracks() }
                    Button("清空列表") { clearPlaylist() }
                    Divider()
                    Button("导入播放列表...") { importPlaylist() }
                    Button("导出播放列表...") { exportPlaylist() }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .frame(height: 24)

            PlaylistSearchField(text: $query)
                .frame(maxWidth: .infinity)
                .frame(height: 24)
                .padding(.horizontal, 6)
                .padding(.bottom, 4)
        }
        .background(TTPlayerClassicColors.controlBackground)
        .zIndex(1)
        .alert("新建列表", isPresented: $namingList) {
            TextField("名称", text: $newListName)
            Button("创建") {
                onCreateList(newListName)
                newListName = ""
            }
            Button("取消", role: .cancel) {
                newListName = ""
            }
        }
    }

    private func importPlaylist() {
        FileOpener.openPlaylist { url in
            guard let url else { return }
            onImportList(url)
        }
    }

    private func exportPlaylist() {
        let name = playlist.name + ".m3u"
        FileOpener.savePlaylist(suggestedName: name) { url in
            guard let url else { return }
            onExportList(url)
        }
    }

    private var listView: some View {
        List(rows, selection: $selection) { row in
            PlaylistRowView(
                index: row.index + 1,
                track: row.track,
                isPlaying: row.track.id == currentTrackID
            )
            .tag(row.track.id)
            .contextMenu {
                Button("删除") {
                    if selection.isEmpty || !selection.contains(row.track.id) {
                        playlist.remove(ids: [row.track.id])
                        selection.remove(row.track.id)
                    } else {
                        deleteSelectedTracks()
                    }
                }
            }
            .simultaneousGesture(TapGesture(count: 2).onEnded {
                playlist.jumpTo(index: row.index)
                onTrackSelected?(row.track)
            })
            .listRowBackground(
                row.track.id == currentTrackID
                    ? TTPlayerClassicColors.listSelection.opacity(0.85)
                    : Color.clear
            )
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .onDeleteCommand { deleteSelectedTracks() }
    }

    private var statusBar: some View {
        HStack {
            Text("\(playlist.tracks.count) 首")
            Spacer()
            Text(formatTime(totalDuration))
            Text("·")
            Button(playlist.playMode.rawValue) {
                if let onCyclePlayMode {
                    onCyclePlayMode()
                } else {
                    playlist.cyclePlayMode()
                }
            }
            .buttonStyle(.plain)
            .help("点击切换播放模式")
        }
        .font(.system(size: 10, design: .monospaced))
        .foregroundColor(TTPlayerClassicColors.secondaryText)
        .padding(.horizontal, 8)
        .frame(height: 18)
        .background(TTPlayerClassicColors.secondaryBackground)
    }

    private static func matches(_ track: Track, query: String) -> Bool {
        let fields = [
            track.title,
            track.artist ?? "",
            track.album ?? "",
            track.displayName,
            track.url.deletingPathExtension().lastPathComponent
        ]
        return fields.contains { $0.localizedStandardContains(query) }
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

    private func toolbarMenu<Content: View>(_ title: String, maxWidth: CGFloat? = nil, @ViewBuilder content: () -> Content) -> some View {
        Menu(content: content) {
            HStack(spacing: 2) {
                Text(title)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .semibold))
                    .opacity(0.7)
            }
            .font(.system(size: 11))
            .foregroundColor(TTPlayerClassicColors.primaryText)
            .frame(maxWidth: maxWidth, alignment: .leading)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize(horizontal: maxWidth == nil, vertical: true)
    }

    private func clearPlaylist() {
        if let onClear {
            onClear()
        } else {
            playlist.clear()
        }
    }

    private func deleteSelectedTracks() {
        if selection.isEmpty, let current = currentTrackID {
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

