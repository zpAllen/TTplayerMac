# TTPlayer for macOS

> 千千静听 macOS 版 - 重现经典，致敬情怀

## 项目简介

基于对 TTPlayer v5.7.9 (Windows) 的逆向分析，使用 Swift + SwiftUI 重构的 macOS 原生版本。

**设计理念：**
- 保留 Windows 经典 UI 风格
- 使用现代 macOS 技术栈
- 专注核心音乐播放功能

## 功能特性

### 已实现 ✅
- [ ] 基础音频播放（AVFoundation）
- [ ] LRC 歌词解析与同步
- [ ] 经典 UI 界面
- [ ] 频谱可视化

### 计划中 🔄
- [ ] 全局快捷键
- [ ] 播放列表管理
- [ ] 桌面歌词
- [ ] 在线歌词搜索
- [ ] 均衡器

## 技术栈

- **语言：** Swift 5.9+
- **框架：** SwiftUI, AVFoundation, AppKit
- **最低系统：** macOS 14.0+
- **开发工具：** Xcode 15+

## 项目结构

```
TTPlayer-macOS/
├── Sources/
│   ├── App/                    # 应用入口
│   │   ├── TTPlayerApp.swift
│   │   └── AppDelegate.swift
│   ├── Models/                 # 数据模型
│   │   ├── Track.swift
│   │   ├── Playlist.swift
│   │   └── LyricDocument.swift
│   ├── Views/                  # 界面组件
│   │   ├── Classic/           # 经典 UI 风格
│   │   │   ├── ClassicMainWindow.swift
│   │   │   ├── ClassicLyricWindow.swift
│   │   │   ├── ClassicPlaylistView.swift
│   │   │   ├── SpectrumView.swift
│   │   │   └── ClassicProgressBar.swift
│   │   └── Components/        # 通用组件
│   ├── ViewModels/            # 业务逻辑
│   │   ├── AudioPlayer.swift
│   │   ├── PlaylistManager.swift
│   │   └── LyricSyncEngine.swift
│   ├── Services/              # 服务层
│   │   ├── LyricSearchEngine.swift
│   │   └── AudioAnalyzer.swift
│   └── Utilities/             # 工具类
│       ├── LRCParser.swift
│       ├── Extensions.swift
│       └── ClassicColors.swift
├── Resources/
│   └── Assets.xcassets/
└── Tests/
```

## 开发路线图

### MVP 阶段（2周）
**Week 1:**
- [x] 项目架构搭建
- [ ] 音频播放引擎
- [ ] 基础 UI 框架
- [ ] 播放控制

**Week 2:**
- [ ] LRC 解析器
- [ ] 歌词同步引擎
- [ ] 歌词窗口
- [ ] 播放列表

### 完善阶段（4周）
- [ ] 频谱可视化
- [ ] 全局快捷键
- [ ] 桌面歌词
- [ ] 均衡器
- [ ] 配置持久化

## 构建与运行

```bash
# 克隆项目
git clone <repo-url>
cd TTPlayer-macOS

# 使用 Xcode 打开
open TTPlayer.xcodeproj

# 或使用命令行构建
xcodebuild -scheme TTPlayer -configuration Debug
```

## 逆向分析文档

详细的 Windows 版逆向分析报告：
- [歌词解析分析](../TTPlayer/ReverseNotes/01_LyricParsing.md)
- [LRC 解析器详解](../TTPlayer/ReverseNotes/02_LRC_Parser_Analysis.md)
- [macOS 重构架构](../TTPlayer/docs/macOS_Refactoring_Architecture.md)

## 参考资料

- [千千静听官网（历史）](http://www.ttplayer.com/)
- [LRC 歌词格式规范](https://en.wikipedia.org/wiki/LRC_(file_format))
- [AVFoundation 官方文档](https://developer.apple.com/av-foundation/)

## 致谢

感谢千千静听（TTPlayer）为我们带来的美好回忆。

## 许可

本项目仅供学习和研究使用。

---

**开发日志：** 2026-10-17 项目启动
