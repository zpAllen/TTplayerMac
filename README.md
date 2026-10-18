# TTPlayer for macOS

> 千千静听 macOS 版。按 Windows 版 TTPlayer 5.7 的播放逻辑和界面习惯，用 Swift 重写。

仓库：<https://github.com/zpAllen/TTplayerMac>

最低系统：**macOS 14**。界面按 Apple 芯片编译；Intel Mac 需要按文末打通用包。

**维护约定：** 播放、歌词、封面、列表、均衡器、快捷键或打包方式有变化时，同步改下面的「功能」和「使用方法」。不要把 README 留在旧行为上。

## 功能

- 播放 MP3、M4A、AAC、WAV、AIFF、FLAC、ALAC、APE、OGG。可多选文件，也可以选整个文件夹（含子目录）。
- 播放、暂停、停止、上一首、下一首、进度拖动、音量、静音。
- 开始播放淡入约 0.3 秒，暂停淡出约 0.5 秒，停止淡出约 0.8 秒。手动切歌先短淡出再淡入，不会卡住切歌。
- 读到 `replaygain_track_gain` / `replaygain_track_peak` 时按峰值限制调整响度，再乘用户音量。菜单「播放 → 音量增益」可关。默认开。
- 播放模式：顺序、列表循环、单曲循环、随机。上一首 / 下一首始终按列表左右切歌。单曲循环只在一首播完后重播当前这首。
- 还没有播过任何歌时，点播放会从列表里随机挑一首。已经在播或暂停过，则接着当前这首。
- 可以有多份播放列表：新建、切换、删除。最后一份不能删。退出后记住全部列表和当前是哪一份。
- 列表可搜索、删除、排序、清空。可以导入、导出 M3U。文件可以拖进窗口。
- 频谱使用正在播放的声音。停止时频谱是空的。颜色可在「窗口 → 频谱颜色」里换成绿、蓝或琥珀。
- 自绘界面里，有封面时显示在频谱左侧（ID3 APIC 等），没有封面时频谱铺满。原版皮肤里，频谱画在皮肤预留的可视区域。
- 歌词优先用文件内嵌内容（例如 MP3 的 ID3 USLT，内容可以是 LRC）。没有内嵌歌词时，再找歌曲同目录和 `~/Music/Lyrics` 里的 `.lrc`。
- 歌词窗口可以给当前歌曲指定一个 LRC，并记住。下次播放这首歌仍用这个文件。支持 UTF-8 和 GB18030。
- 歌词窗口可以整体提前或延后最多 10 秒，并记住。这个偏移和文件里的 `[offset:]` 分开。「存为 LRC」按听到的时间写出新文件，不改音频标签。
- 桌面歌词在屏幕底部。字号、颜色和透明度在歌词窗口里调。没有歌词时显示「暂无歌词」。
- 十段均衡器，带预设。手动拖动频段会进入「自定义」，不会把曲线清掉。
- 找到原版 `ttpres.dll` 时，主窗口用里面的默认皮肤（按钮、进度、音量、时间、频谱位置都按 `Skin.xml`）。列表、歌词、均衡器停在播放器下面，一次只显示一个。歌词和均衡器标题栏右侧的窗口图标可以再拆成单独窗口。找不到皮肤时，退回自绘界面。皮肤图不打进安装包。
- 窗口可置顶。列表可以收起。
- 菜单栏有播放、上一首、下一首和当前歌名。系统「正在播放」会收到标题、进度、封面，以及播放、暂停、上下首和拖动进度。
- 全局快捷键可以在「窗口 → 快捷键」里改，并记住。

尚未做：在线搜歌词、格式转换、按专辑归档的音乐库、歌词/列表/均衡器窗口的位图皮肤、随意切换 `.skn`、Windows 插件解码、FreeDB。

## 使用方法

打开后用菜单「文件 → 打开音乐文件或文件夹」（Command+O），选文件或目录。也可以把文件、文件夹拖进窗口。

在仓库目录启动时，程序会向上查找 `TTPlayerv5.7.9/ttpres.dll`，也会找同级目录 `TTPlayer/TTPlayerv5.7.9/ttpres.dll`。找到后主窗口就是原版默认皮肤，圆角是透明的。把窗口拉宽时，皮肤按比例铺满宽度，下面的列表、歌词或均衡器跟着铺满剩下的高度。空白处可以拖动窗口。皮肤上的按钮：播放/暂停、上一首、下一首、停止、静音、列表、歌词、均衡器。右上角只留最小化和关闭。最右边的音符按钮开关桌面歌词，打开时按钮呈按下状态。进度和音量可以直接拖。

打包后的 `TTPlayer.app` 也可以自己指定来源（二选一，目录优先）：

```bash
defaults write com.ttplayer.macos skin.dll /path/to/ttpres.dll
defaults write com.ttplayer.macos skin.directory /path/to/Skin
```

`skin.directory` 是一份解开的皮肤目录，里面要有 `Skin.xml` 和对应的 bmp。没有皮肤时用自绘界面：控制栏从左到右是上一首、播放/暂停、停止、下一首、打开、音量、播放模式、列表、歌词、均衡器、桌面歌词。标题栏右侧是置顶、最小化和退出。

列表工具栏是添加、排序和列表名，下面一整行是搜索。列表名菜单里可以切换、新建、删除列表，删除选中的歌，清空列表，以及导入或导出 M3U。右键一首歌也可以删除。

| 操作 | 做法 |
| --- | --- |
| 播放 / 暂停 | 播放按钮，或空格。菜单栏图标同样可以 |
| 停止 | 方块按钮，或 Command+S。再点播放从这首开头开始 |
| 上一首 / 下一首 | 左右箭头按钮，或 Command+左右方向键 |
| 音量 | 滑条，或 Command+上下方向键。Command+M 静音 |
| 音量增益 | 菜单「播放 → 音量增益」。有 ReplayGain 标签时才改变响度 |
| 播放模式 | 列表右下角文字，或自绘控制栏的模式按钮，或菜单「播放 → 播放模式」。顺序 → 随机 → 单曲循环 → 列表循环 |
| 显示或收起列表 | 列表按钮，或 Command+Shift+P。和歌词、均衡器互相切换，下面不同时展开 |
| 多份列表 | 列表工具栏上的列表名。最后一份不能删 |
| 导入 / 导出列表 | 同一菜单，或「文件」菜单。格式是 M3U |
| 歌词 | 歌词按钮，或 Command+L。下面只显示这一个，列表和均衡器会让开。再点一次收起。标题栏窗口图标可单独打开 |
| 指定这首歌的 LRC | 歌词窗口「指定歌词」 |
| 歌词提前或延后 | 歌词窗口的偏移滑条，范围 ±10 秒。归零恢复 |
| 把歌词存成文件 | 歌词窗口「存为 LRC」 |
| 搜索列表 | 列表按钮下面那一行搜索框，按歌名、歌手、专辑或文件名过滤 |
| 删除歌曲 | 右键这首歌，或选中后按 Delete。也可以在列表名菜单里删选中、清空 |
| 桌面歌词 | 主窗口最右边的音符按钮，或歌词窗口「桌面歌词」，或 Command+Shift+D。字号、颜色、透明度在歌词窗口 |
| 频谱颜色 | 菜单「窗口 → 频谱颜色」 |
| 均衡器 | 均衡器按钮，或 Command+E。下面只显示这一个。再点一次收起。标题栏窗口图标可单独打开 |
| 总在最前 | 标题栏「顶」 |
| 改全局快捷键 | 菜单「窗口 → 快捷键」。点「修改」后按下新的组合键 |

菜单栏图标可以播放、切歌、回到主窗口。正在播放信息（标题、封面、进度，以及系统媒体键）在打包成 `TTPlayer.app` 后会进控制中心；从终端直接跑二进制时，系统有时不接收。

全局快捷键需要辅助功能权限（系统设置 → 隐私与安全性 → 辅助功能）。默认按键如下，可在「窗口 → 快捷键」里改：

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
