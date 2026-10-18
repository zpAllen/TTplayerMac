# TTPlayer for macOS

> 千千静听 macOS 版。按 Windows 版 TTPlayer 5.7 的播放逻辑和界面习惯，用 Swift 重写。

仓库：<https://github.com/zpAllen/TTplayerMac>

最低系统：**macOS 14**。界面按 Apple 芯片编译；Intel Mac 需要按文末打通用包。

**维护约定：** 播放、歌词、封面、列表、均衡器、快捷键或打包方式有变化时，同步改下面的「功能」和「使用方法」。不要把 README 留在旧行为上。

## 功能

- 播放 MP3、M4A、AAC、WAV、AIFF、FLAC、ALAC、APE、OGG。可多选文件，也可以选整个文件夹（含子目录）。
- 播放、暂停、停止、上一首、下一首、进度拖动、音量、静音。
- 播放模式：顺序、列表循环、单曲循环、随机。上一首 / 下一首始终按列表左右切歌。单曲循环只在一首播完后重播当前这首。
- 还没有播过任何歌时，点播放会从列表里随机挑一首。已经在播或暂停过，则接着当前这首。
- 列表可搜索、删除、排序、清空，退出后记住曲目和播放模式。文件可以拖进窗口。
- 频谱使用正在播放的声音。停止时频谱是空的。
- 有封面时显示在频谱左侧（ID3 APIC 等）。没有封面时频谱铺满。
- 歌词优先用文件内嵌内容（例如 MP3 的 ID3 USLT，内容可以是 LRC）。没有内嵌歌词时，再找歌曲同目录和 `~/Music/Lyrics` 里的 `.lrc`。
- 歌词窗口可以给当前歌曲指定一个 LRC，并记住。下次播放这首歌仍用这个文件。支持 UTF-8 和 GB18030。
- 桌面歌词在屏幕底部，已唱部分从左向右变绿。没有歌词时显示「暂无歌词」。
- 十段均衡器，带预设。手动拖动频段会进入「自定义」，不会把曲线清掉。
- 窗口可置顶。列表可以收起，收起后窗口高度回到播放器本身。

尚未做：在线搜歌词、格式转换、音乐库、原版皮肤位图。

## 使用方法

打开后从控制栏的文件夹按钮，或菜单「文件 → 打开音乐文件或文件夹」（Command+O），选文件或目录。也可以把文件、文件夹拖进窗口。

控制栏从左到右：上一首、播放/暂停、停止、下一首、打开、音量、播放模式、列表、歌词、均衡器、桌面歌词。标题栏右侧是置顶、最小化和退出。

| 操作 | 做法 |
| --- | --- |
| 播放 / 暂停 | 播放按钮，或空格 |
| 停止 | 方块按钮，或 Command+S。再点播放从这首开头开始 |
| 上一首 / 下一首 | 左右箭头按钮，或 Command+左右方向键 |
| 音量 | 滑条，或 Command+上下方向键。Command+M 静音 |
| 播放模式 | 点「顺序 / 列表 / 单曲 / 随机」循环切换 |
| 显示或收起列表 | 列表按钮，或 Command+Shift+P |
| 歌词窗口 | 歌词按钮，或 Command+L |
| 指定这首歌的 LRC | 歌词窗口右上角「指定歌词」 |
| 桌面歌词 | 「桌词」，或 Command+Shift+D |
| 均衡器 | 均衡器按钮，或 Command+E |
| 总在最前 | 标题栏「顶」 |

全局快捷键需要辅助功能权限（系统设置 → 隐私与安全性 → 辅助功能）：

| 快捷键 | 作用 |
| --- | --- |
| Command+Option+P | 播放 / 暂停 |
| Command+Option+左 / 右 | 上一首 / 下一首 |
| Command+Option+上 / 下 | 音量减 / 加 |
| Command+Option+L | 桌面歌词 |

没有权限时，窗口里的按钮和菜单仍然可用。

## 本地开发

需要 Swift 5.9 或更新（Xcode 15+ 自带的工具链即可）。仓库是 Swift Package，没有 Xcode 工程。

```bash
git clone https://github.com/zpAllen/TTplayerMac.git
cd TTplayerMac

# 编译调试版并在终端启动，日志直接打在这个窗口
swift build
.build/debug/TTPlayer
```

改完代码后先退出正在运行的程序，再执行上面两条。同时开着旧进程时，看到的仍是上一次编译的界面。

发布用的优化构建：

```bash
swift build -c release
```

可执行文件在 `.build/arm64-apple-macosx/release/TTPlayer`。这是命令行程序，不要把这个文件直接发给别人。

## 打包给别人使用

打成 `TTPlayer.app` 再压缩。本机没有 Apple 开发者证书时，只能临时签名。对方第一次打开从网络下载的应用，需要右键「打开」，不能直接双击。

Apple 芯片：

```bash
swift build -c release

APP="TTPlayer.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

cp .build/arm64-apple-macosx/release/TTPlayer "$APP/Contents/MacOS/TTPlayer"

cat > "$APP/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>TTPlayer</string>
  <key>CFBundleIdentifier</key>
  <string>com.ttplayer.macos</string>
  <key>CFBundleName</key>
  <string>千千静听</string>
  <key>CFBundleDisplayName</key>
  <string>千千静听</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
EOF

codesign --force --sign - "$APP"
ditto -c -k --keepParent "$APP" TTPlayer.zip
```

把 `TTPlayer.zip` 发出去。对方解压后把 `TTPlayer.app` 拖进「应用程序」。

Intel 与 Apple 芯片都能跑的包，编译改成：

```bash
swift build -c release --arch arm64 --arch x86_64
```

复制 `.build/apple-macosx/release/TTPlayer`，不要用 `arm64-apple-macosx` 下面那个。

## 源码布局

```
Sources/
├── App/            # 入口、菜单
├── Models/         # 曲目、列表、LRC
├── ViewModels/     # 播放、均衡器、频谱、歌词同步
├── Views/Classic/  # 主窗口、列表、歌词、均衡器、桌面歌词
├── Services/       # 歌词查找、桌面歌词、全局快捷键
└── Utilities/      # 配色、文件选择
```

## 许可

本项目仅供学习和研究使用。
