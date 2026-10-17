# TTPlayer 快速启动指南（无需 Xcode）

## 🚀 三种启动方式

### 方式 1：命令行启动（最简单）

```bash
cd /Users/sirzhang/Ai/ReaWork/TTPlayer-macOS

# 构建并运行
./build_and_run.sh
```

### 方式 2：Swift 命令直接运行

```bash
cd /Users/sirzhang/Ai/ReaWork/TTPlayer-macOS

# 编译
swift build

# 运行
.build/debug/TTPlayer
```

### 方式 3：生成 Xcode 项目（推荐开发）

```bash
cd /Users/sirzhang/Ai/ReaWork/TTPlayer-macOS

# 生成 .xcodeproj 文件
swift package generate-xcodeproj

# 打开项目
open TTPlayer.xcodeproj
```

生成后就可以双击 `TTPlayer.xcodeproj` 打开了！

---

## 📝 注意事项

### 如果遇到构建错误

**问题 1：缺少 Command Line Tools**
```bash
# 安装
xcode-select --install
```

**问题 2：Swift 版本过低**
```bash
# 检查版本（需要 5.9+）
swift --version

# 更新 Xcode 到最新版本
```

**问题 3：找不到 SwiftUI**
```bash
# 确保 macOS 14.0+
sw_vers

# 如果系统版本低，修改 Package.swift:
# .macOS(.v13) 或 .macOS(.v12)
```

---

## 🔧 开发模式

### 热重载（监听文件变化自动重新编译）

```bash
# 安装 nodemon（需要 Node.js）
npm install -g nodemon

# 监听变化并自动重新运行
nodemon --exec swift run --ext swift
```

### 调试模式

```bash
# 编译 debug 版本
swift build -c debug

# 使用 lldb 调试
lldb .build/debug/TTPlayer
```

### 发布版本

```bash
# 编译 release 版本（优化性能）
swift build -c release

# 运行
.build/release/TTPlayer
```

---

## 📦 打包为应用

### 创建 .app 包

```bash
# 创建应用结构
mkdir -p TTPlayer.app/Contents/MacOS
mkdir -p TTPlayer.app/Contents/Resources

# 复制可执行文件
swift build -c release
cp .build/release/TTPlayer TTPlayer.app/Contents/MacOS/

# 创建 Info.plist
cat > TTPlayer.app/Contents/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>TTPlayer</string>
    <key>CFBundleIdentifier</key>
    <string>com.ttplayer.macos</string>
    <key>CFBundleName</key>
    <string>TTPlayer</string>
    <key>CFBundleVersion</key>
    <string>0.1</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# 现在可以双击运行 TTPlayer.app
open TTPlayer.app
```

---

## ⚡ 性能对比

| 方式 | 编译时间 | 启动速度 | 适用场景 |
|------|---------|---------|---------|
| swift run | ~10s | 快 | 快速测试 |
| .build/debug | ~10s + 缓存 | 很快 | 开发调试 |
| .build/release | ~30s | 最快 | 发布版本 |
| Xcode | ~15s | 快 | GUI 开发 |

---

## 🎯 推荐工作流

### 日常开发
```bash
# 终端运行，实时查看输出
swift run
```

### 界面调整
```bash
# 使用 Xcode（可视化预览）
open TTPlayer.xcodeproj
```

### 测试发布
```bash
# 打包为 .app
./package_app.sh
```

---

现在你可以直接在终端运行了！
