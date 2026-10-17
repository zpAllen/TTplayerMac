//
//  ClassicMainWindow.swift
//  TTPlayer for macOS
//
//  经典主窗口
//

import SwiftUI

/// 经典主窗口视图
struct ClassicMainWindow: View {
    @StateObject private var manager = PlaybackManager()
    @State private var showPlaylist = false
    @State private var showEqualizer = false

    var body: some View {
        VStack(spacing: 0) {
            // 频谱可视化
            SpectrumView()
                .frame(height: 60)

            // 歌曲信息区
            HStack {
                Text(manager.player.currentTrack?.displayName ?? "TTPlayer for macOS")
                    .font(.system(size: 12))
                    .foregroundColor(TTPlayerClassicColors.primaryText)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 8)
            .frame(height: 20)
            .background(TTPlayerClassicColors.secondaryBackground)

            // 进度条
            ClassicProgressBar(
                current: manager.player.currentTime,
                total: manager.player.duration,
                onSeek: { time in
                    manager.player.seek(to: time)
                }
            )
            .frame(height: 24)

            // 控制栏
            ClassicControlBar(
                manager: manager,
                showPlaylist: $showPlaylist,
                showEqualizer: $showEqualizer
            )
        }
        .frame(width: 327, height: 141)
        .background(TTPlayerClassicColors.mainBackground)
        .sheet(isPresented: $showPlaylist) {
            ClassicPlaylistView(manager: manager, isPresented: $showPlaylist)
        }
        .sheet(isPresented: $showEqualizer) {
            ClassicEqualizerWindow(equalizer: manager.equalizer)
        }
    }
}

// MARK: - Preview

struct ClassicMainWindow_Previews: PreviewProvider {
    static var previews: some View {
        ClassicMainWindow()
            .preferredColorScheme(.dark)
    }
}
