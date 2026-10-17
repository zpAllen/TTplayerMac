//
//  ClassicButton.swift
//  TTPlayer for macOS
//
//  经典按钮组件
//

import SwiftUI

/// 经典按钮样式
struct ClassicButton: View {
    let icon: String
    var isLarge: Bool = false
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: isLarge ? 20 : 14))
                .foregroundColor(isActive ? TTPlayerClassicColors.accent : TTPlayerClassicColors.primaryText)
                .frame(
                    width: isLarge ? 32 : 24,
                    height: isLarge ? 32 : 24
                )
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(isActive ? 0.15 : 0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(
                            Color.white.opacity(isActive ? 0.3 : 0.2),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

/// 经典控制栏
struct ClassicControlBar: View {
    @ObservedObject var manager: PlaybackManager
    @Binding var showPlaylist: Bool
    @Binding var showEqualizer: Bool

    var body: some View {
        HStack(spacing: 12) {
            // 上一曲
            ClassicButton(icon: "backward.fill") {
                manager.playPrevious()
            }

            // 播放/暂停
            ClassicButton(
                icon: manager.player.isPlaying ? "pause.fill" : "play.fill",
                isLarge: true
            ) {
                manager.player.togglePlayPause()
            }

            // 下一曲
            ClassicButton(icon: "forward.fill") {
                manager.playNext()
            }

            // 停止
            ClassicButton(icon: "stop.fill") {
                manager.player.stop()
            }

            Spacer()

            // 音量控制
            HStack(spacing: 4) {
                Button(action: manager.player.toggleMute) {
                    Image(systemName: manager.player.isMuted ? "speaker.slash.fill" : "speaker.wave.1.fill")
                        .font(.system(size: 12))
                        .foregroundColor(TTPlayerClassicColors.primaryText)
                }
                .buttonStyle(.plain)

                Slider(value: Binding(
                    get: { Double(manager.player.volume) },
                    set: { manager.player.setVolume(Float($0)) }
                ), in: 0...1)
                    .frame(width: 60)
                    .tint(TTPlayerClassicColors.accent)

                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 12))
                    .foregroundColor(TTPlayerClassicColors.primaryText)
            }

            Spacer()

            // 播放列表
            ClassicButton(icon: "music.note.list", isActive: showPlaylist) {
                showPlaylist.toggle()
            }

            // 均衡器
            ClassicButton(icon: "slider.horizontal.3", isActive: showEqualizer) {
                showEqualizer.toggle()
            }

            // 打开文件
            ClassicButton(icon: "folder.fill") {
                openFilePicker()
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 40)
        .background(TTPlayerClassicColors.controlBackground)
    }

    /// 打开文件选择器
    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            .audio,
            .mp3,
            .mpeg4Audio
        ]
        panel.message = "选择音乐文件"

        if panel.runModal() == .OK {
            Task {
                await manager.importTracks(from: panel.urls)
            }
        }
    }
}

// MARK: - Preview

struct ClassicButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            HStack(spacing: 12) {
                ClassicButton(icon: "backward.fill") {}
                ClassicButton(icon: "play.fill", isLarge: true) {}
                ClassicButton(icon: "forward.fill") {}
                ClassicButton(icon: "stop.fill") {}
            }

            HStack(spacing: 12) {
                ClassicButton(icon: "music.note.list") {}
                ClassicButton(icon: "music.note.list", isActive: true) {}
                ClassicButton(icon: "slider.horizontal.3") {}
                ClassicButton(icon: "gearshape.fill") {}
            }
        }
        .padding()
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
}
