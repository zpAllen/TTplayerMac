# 快速启动指南

## 立即运行项目

### 1. 创建 Xcode 项目

```bash
cd /Users/sirzhang/Ai/ReaWork/TTPlayer-macOS
```

在 Xcode 中：
1. 打开 Xcode
2. File → New → Project
3. 选择 macOS → App
4. 配置：
   - Product Name: `TTPlayer`
   - Interface: `SwiftUI`
   - Language: `Swift`
   - 保存到：`/Users/sirzhang/Ai/ReaWork/TTPlayer-macOS`

### 2. 导入源代码

将已创建的源文件添加到 Xcode 项目：

1. 删除 Xcode 自动生成的 `ContentView.swift`
2. 拖拽整个 `Sources` 文件夹到项目中
3. 确保选中 "Copy items if needed"

### 3. 配置项目设置

在项目设置中：

**General 标签：**
- Deployment Target: macOS 14.0
- Bundle Identifier: `com.ttplayer.macos`

**Build Settings 标签：**
- Enable Previews: Yes
- Swift Language Version: Swift 5

**Info.plist 添加：**
```xml
<key>LSMinimumSystemVersion</key>
<string>14.0</string>
<key>NSMicrophoneUsageDescription</key>
<string>用于音频频谱分析</string>
```

### 4. 运行项目

```bash
# 命令行运行
xcodebuild -scheme TTPlayer -configuration Debug

# 或在 Xcode 中按 Cmd+R
```

---

## 当前功能状态

### ✅ 已实现
- [x] 经典 UI 界面框架
- [x] 深色配色方案
- [x] 频谱可视化（模拟数据）
- [x] 进度条组件
- [x] 播放控制按钮
- [x] 音频播放引擎（AVFoundation）
- [x] LRC 解析器
- [x] 播放列表数据模型

### 🔄 部分实现
- [ ] 文件打开功能（需要添加）
- [ ] 歌词窗口（数据模型已完成，UI 待实现）
- [ ] 播放列表 UI（模型已完成，UI 待实现）

### ⏳ 待实现
- [ ] 真实频谱数据接入
- [ ] 全局快捷键
- [ ] 桌面歌词
- [ ] 配置持久化

---

## 测试播放功能

### 方法 1：修改代码添加测试曲目

在 `ClassicMainWindow.swift` 中添加：

```swift
.onAppear {
    // 测试：加载一个音乐文件
    let testURL = URL(fileURLWithPath: "/path/to/your/music.mp3")
    Task {
        if let track = await Track.from(url: testURL) {
            player.load(track: track)
        }
    }
}
```

### 方法 2：添加文件选择器（推荐）

创建 `FileManager+Extensions.swift`：

```swift
import SwiftUI
import UniformTypeIdentifiers

extension View {
    func openMusicFile(completion: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.mp3, .mpeg4Audio, .wav, .aiff]
        
        panel.begin { response in
            if response == .OK {
                completion(panel.url)
            } else {
                completion(nil)
            }
        }
    }
}
```

然后在 `ClassicMainWindow.swift` 添加打开文件按钮。

---

## 目录结构

```
TTPlayer-macOS/
├── TTPlayer.xcodeproj
├── Sources/
│   ├── App/
│   │   └── TTPlayerApp.swift          ✅ 应用入口
│   ├── Models/
│   │   ├── Track.swift                ✅ 曲目模型
│   │   ├── Playlist.swift             ✅ 播放列表
│   │   └── LyricDocument.swift        ✅ 歌词模型
│   ├── Views/
│   │   └── Classic/
│   │       ├── ClassicMainWindow.swift    ✅ 主窗口
│   │       ├── SpectrumView.swift         ✅ 频谱
│   │       ├── ClassicProgressBar.swift   ✅ 进度条
│   │       └── ClassicButton.swift        ✅ 按钮
│   ├── ViewModels/
│   │   └── AudioPlayer.swift          ✅ 播放引擎
│   └── Utilities/
│       └── ClassicColors.swift        ✅ 配色方案
├── Resources/
│   └── Assets.xcassets/
├── README.md
└── CHANGELOG.md
```

---

## 常见问题

### Q: 编译错误："Cannot find type 'TTPlayerClassicColors'"

**A:** 确保 `ClassicColors.swift` 已添加到项目 Target。在 File Inspector 中勾选 Target Membership。

### Q: 窗口大小不固定

**A:** 检查 `TTPlayerApp.swift` 中的窗口配置：
```swift
.windowStyle(.hiddenTitleBar)
.windowResizability(.contentSize)
```

### Q: 频谱不动

**A:** 这是正常的，当前使用随机数据模拟。真实频谱需要接入 AVAudioEngine。

### Q: 找不到音频文件

**A:** 使用绝对路径或添加文件选择器功能。

---

## 下一步开发建议

### 第1优先级：让它能播放音乐

1. **添加文件打开功能**
   ```swift
   // 在控制栏添加"打开文件"按钮
   ClassicButton(icon: "folder") {
       openMusicFile { url in
           guard let url = url else { return }
           Task {
               if let track = await Track.from(url: url) {
                   player.load(track: track)
                   player.play()
               }
           }
       }
   }
   ```

2. **测试音频播放**
   - 准备一个 MP3 文件
   - 点击打开按钮加载
   - 点击播放按钮测试

### 第2优先级：显示歌词

1. **实现 LyricSyncEngine**
   ```swift
   class LyricSyncEngine: ObservableObject {
       @Published var currentLine: LRCLine?
       private var document: LyricDocument
       
       func update(time: TimeInterval) {
           currentLine = document.currentLine(at: time)
       }
   }
   ```

2. **在主窗口显示当前歌词**
   - 在频谱下方添加歌词显示区
   - 从 AudioPlayer 获取当前时间
   - 实时更新歌词

### 第3优先级：完善播放列表

1. 实现播放列表 UI
2. 支持拖拽文件添加
3. 双击播放
4. 自动播放下一曲

---

## 联系与反馈

有问题或建议？
- 查看逆向分析文档：`../TTPlayer/ReverseNotes/`
- 参考架构设计：`../TTPlayer/docs/macOS_Refactoring_Architecture.md`

---

**开始享受编码吧！🎵**
