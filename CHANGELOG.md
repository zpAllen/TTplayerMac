# 开发日志

## 2026-10-17

### 项目初始化
- ✅ 创建项目目录结构
- ✅ 实现核心数据模型
  - `Track` - 音频曲目模型
  - `Playlist` - 播放列表模型  
  - `LyricDocument` - LRC 歌词文档模型
- ✅ 实现业务逻辑层
  - `AudioPlayer` - 音频播放引擎（AVFoundation）
- ✅ 实现经典 UI 组件
  - `ClassicColors` - 经典配色方案
  - `SpectrumView` - 频谱可视化
  - `ClassicProgressBar` - 进度条
  - `ClassicButton` - 按钮组件
  - `ClassicControlBar` - 控制栏
  - `ClassicMainWindow` - 主窗口
- ✅ 配置应用入口
  - `TTPlayerApp` - 应用主入口
  - 快捷键绑定
  - 菜单配置

### 技术要点

#### LRC 解析器
基于 Windows 版逆向分析，实现了完整的 LRC 解析：
```swift
// 支持的格式：
[ti:标题]
[ar:艺术家]
[al:专辑]
[by:制作者]
[offset:毫秒偏移]
[mm:ss.xx]歌词内容
```

时间转换算法（逆向自 Windows 版）：
```swift
timestamp = minutes * 60 + seconds + metadata.offset
```

#### 音频播放
使用 AVFoundation 替代 Windows 的 BASS Audio：
- AVPlayer 提供基础播放功能
- 每 0.1 秒更新播放进度
- 支持音量控制和静音
- 监听播放完成事件

#### 经典 UI
完全复刻 Windows 版视觉风格：
- 配色：深黑背景 #1A1A1A，经典蓝 #5BC0DE
- 频谱：绿色渐变 #00FF00 → #006600
- 窗口：固定 327x141 像素
- 字体：系统等宽字体（时间显示）

### 待实现功能

#### 高优先级
- [ ] 文件选择器（打开音乐文件）
- [ ] 播放列表 UI
- [ ] 歌词窗口
- [ ] 歌词同步引擎

#### 中优先级
- [x] **真实频谱数据（AVAudioEngine + FFT）** ✨
- [x] **10段均衡器（AVAudioUnitEQ）** ✨
- [x] **增强型音频播放器（完整 DSP 链）** ✨
- [ ] 播放列表持久化
- [ ] 全局快捷键
- [ ] 桌面歌词

#### 低优先级
- [ ] 在线歌词搜索
- [ ] 皮肤系统
- [ ] 插件支持

---

## 2026-10-17 (下午)

### 音频引擎逆向分析完成
- ✅ 分析 BASS Audio Library 架构
- ✅ 识别 14 个音频解码器插件
- ✅ 理解插件加载机制
- ✅ 分析 ReplayGain 实现
- ✅ 理解 10 段均衡器配置
- ✅ 分析频谱 FFT 算法

**文档输出：**
- `ReverseNotes/03_Audio_Engine_Analysis.md` (完整音频引擎分析)

### macOS 音频组件实现
- ✅ `AudioEqualizer.swift` - 完整的 10 段均衡器
  - 10 个标准频段（31Hz ~ 16kHz）
  - 10 个预设（摇滚/流行/爵士/古典等）
  - ±12 dB 增益范围
  - 配置持久化
  
- ✅ `SpectrumAnalyzer.swift` - 真实 FFT 频谱分析
  - 使用 Accelerate 框架
  - 汉明窗处理
  - 对数频率分布
  - 平滑惯性处理
  
- ✅ `EnhancedAudioPlayer.swift` - 增强型播放器
  - AVAudioEngine 完整音频图
  - 集成均衡器和频谱分析
  - 实时 tap 处理
  
- ✅ `ClassicEqualizerWindow.swift` - 均衡器 UI
- ✅ `EnhancedSpectrumView.swift` - 频谱 UI

### 已知问题
1. 频谱视图目前使用随机数据，需要接入真实音频分析
2. 播放列表操作尚未与 AudioPlayer 集成
3. 窗口样式需要进一步调整以完全隐藏标题栏

### 下一步计划
1. 实现文件打开功能
2. 完成播放列表 UI
3. 集成 LRC 歌词显示
4. 测试音频播放稳定性

---

## 参考
- [Windows 版逆向分析](../../TTPlayer/ReverseNotes/)
- [macOS 重构架构文档](../../TTPlayer/docs/macOS_Refactoring_Architecture.md)
