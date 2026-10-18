//
//  AppDelegate.swift
//  TTPlayer for macOS
//
//  启动时检查全局快捷键所需的辅助功能权限
//

import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if !AXIsProcessTrusted() {
            print("全局快捷键需要辅助功能权限。播放窗口不依赖这项权限。")
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
