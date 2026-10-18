//
//  AppDelegate.swift
//  TTPlayer for macOS
//
//  启动时检查全局快捷键所需的辅助功能权限
//

import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 从终端直接跑二进制时，系统可能当成禁止激活的进程。
        // 窗口能点，但输入框拿不到键盘。先设成普通应用再前置。
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()

        if !AXIsProcessTrusted() {
            print("全局快捷键需要辅助功能权限。播放窗口不依赖这项权限。")
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
