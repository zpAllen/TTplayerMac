//
//  FileOpener.swift
//  TTPlayer for macOS
//
//  文件选择器工具
//

import SwiftUI
import UniformTypeIdentifiers

/// 文件打开工具
struct FileOpener {
    /// 打开音频文件
    static func openAudioFiles(completion: @escaping ([URL]) -> Void) {
        let panel = NSOpenPanel()
        panel.message = "选择音频文件"
        panel.prompt = "打开"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            .mp3,
            .mpeg4Audio,  // AAC, M4A
            .wav,
            .aiff,
            UTType(filenameExtension: "flac") ?? .audio,
            UTType(filenameExtension: "ape") ?? .audio,
            UTType(filenameExtension: "ogg") ?? .audio,
        ]

        panel.begin { response in
            if response == .OK {
                completion(panel.urls)
            } else {
                completion([])
            }
        }
    }

    /// 打开文件夹
    static func openFolder(completion: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.message = "选择包含音乐的文件夹"
        panel.prompt = "选择"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false

        panel.begin { response in
            if response == .OK {
                completion(panel.url)
            } else {
                completion(nil)
            }
        }
    }

    /// 打开歌词文件
    static func openLyricFile(completion: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.message = "选择 LRC 歌词文件"
        panel.prompt = "打开"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            UTType(filenameExtension: "lrc") ?? .plainText
        ]

        panel.begin { response in
            if response == .OK {
                completion(panel.url)
            } else {
                completion(nil)
            }
        }
    }
}

// MARK: - View Extension

extension View {
    /// 添加拖拽文件支持
    func onDropAudioFiles(perform action: @escaping ([URL]) -> Void) -> some View {
        self.onDrop(of: [.fileURL], isTargeted: nil) { providers in
            var urls: [URL] = []

            let group = DispatchGroup()

            for provider in providers {
                group.enter()
                _ = provider.loadObject(ofClass: URL.self) { url, error in
                    defer { group.leave() }

                    guard let url = url, error == nil else { return }

                    // 检查是否是音频文件
                    let ext = url.pathExtension.lowercased()
                    if ["mp3", "m4a", "aac", "wav", "aiff", "flac", "ape", "ogg"].contains(ext) {
                        urls.append(url)
                    }
                }
            }

            group.notify(queue: .main) {
                if !urls.isEmpty {
                    action(urls)
                }
            }

            return true
        }
    }
}
