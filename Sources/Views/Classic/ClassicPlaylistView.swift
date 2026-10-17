//
//  ClassicPlaylistView.swift
//  TTPlayer for macOS
//
//  经典播放列表视图
//

import SwiftUI

/// 经典播放列表视图
struct ClassicPlaylistView: View {
    @ObservedObject var playlist: Playlist
    @Binding var currentTrack: Track?

    var onTrackSelected: ((Track) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            toolbarView

            // 列表
            listView
        }
        .background(TTPlayerClassicColors.mainBackground)
    }

    // MARK: - Toolbar

    private var toolbarView: some View {
        HStack(spacing: 8) {
            Menu("文件") {
                Button("添加文件...") { openFiles() }
                Button("添加文件夹...") { openFolder() }
                Divider()
                Button("清空列表") { playlist.clear() }
            }
            .font(.system(size: 11))

            Menu("列表") {
                Button("保存列表...") { savePlaylist() }
                Button("加载列表...") { loadPlaylist() }
            }
            .font(.system(size: 11))

            Menu("排序") {
                Button("按名称") { sortByName() }
                Button("按艺术家") { sortByArtist() }
                Button("按时长") { sortByDuration() }
            }
            .font(.system(size: 11))

            Button("删除") {
                deleteSelectedTracks()
            }
            .font(.system(size: 11))

            Spacer()

            // 搜索框
            TextField("搜索", text: .constant(""))
                .textFieldStyle(.plain)
                .frame(width: 120)
                .font(.system(size: 11))
        }
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(TTPlayerClassicColors.controlBackground)
    }

    // MARK: - List

    private var listView: some View {
        List {
            ForEach(Array(playlist.tracks.enumerated()), id: \.element.id) { index, track in
                PlaylistRowView(
                    index: index + 1,
                    track: track,
                    isPlaying: track.id == currentTrack?.id,
                    isCurrent: index == playlist.currentIndex
                )
                .onTapGesture(count: 2) {
                    // 双击播放
                    playlist.jumpTo(index: index)
                    onTrackSelected?(track)
                }
                .listRowBackground(
                    index == playlist.currentIndex
                        ? TTPlayerClassicColors.accent.opacity(0.3)
                        : Color.clear
                )
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Actions

    private func openFiles() {
        FileOpener.openAudioFiles { urls in
            Task {
                for url in urls {
                    if let track = await Track.from(url: url) {
                        playlist.add(track: track)
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
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: nil) else {
            return
        }

        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            if ["mp3", "m4a", "aac", "wav", "aiff"].contains(ext) {
                if let track = await Track.from(url: fileURL) {
                    await MainActor.run {
                        playlist.add(track: track)
                    }
                }
            }
        }
    }

    private func deleteSelectedTracks() {
        // TODO: 实现删除选中项
    }

    private func sortByName() {
        playlist.tracks.sort { $0.title < $1.title }
    }

    private func sortByArtist() {
        playlist.tracks.sort { ($0.artist ?? "") < ($1.artist ?? "") }
    }

    private func sortByDuration() {
        playlist.tracks.sort { $0.duration < $1.duration }
    }

    private func savePlaylist() {
        // TODO: 保存播放列表
    }

    private func loadPlaylist() {
        // TODO: 加载播放列表
    }
}

/// 播放列表行视图
struct PlaylistRowView: View {
    let index: Int
    let track: Track
    let isPlaying: Bool
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 8) {
            // 序号
            Text("\(index)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(TTPlayerClassicColors.tertiaryText)
                .frame(width: 30, alignment: .trailing)

            // 播放状态
            if isPlaying {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 10))
                    .foregroundColor(TTPlayerClassicColors.accent)
                    .frame(width: 16)
            } else {
                Spacer()
                    .frame(width: 16)
            }

            // 歌曲信息
            Text(track.displayName)
                .font(.system(size: 11))
                .foregroundColor(
                    isCurrent ? TTPlayerClassicColors.primaryText : TTPlayerClassicColors.secondaryText
                )
                .lineLimit(1)

            Spacer()

            // 时长
            Text(track.formattedDuration)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(TTPlayerClassicColors.tertiaryText)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Preview

struct ClassicPlaylistView_Previews: PreviewProvider {
    static var previews: some View {
        ClassicPlaylistView(
            playlist: Playlist(name: "测试列表"),
            currentTrack: .constant(nil)
        )
        .frame(width: 400, height: 400)
        .preferredColorScheme(.dark)
    }
}
