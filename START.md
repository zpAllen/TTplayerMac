# 快速开始（1 分钟运行项目）

## 🚀 最简单的方式

打开终端，运行：

```bash
cd /Users/sirzhang/Ai/ReaWork/TTPlayer-macOS
./build_and_run.sh
```

就这么简单！

---

## 📝 详细说明

### 第一次运行需要：

1. **安装 Xcode Command Line Tools**（如果没有）
   ```bash
   xcode-select --install
   ```

2. **运行项目**
   ```bash
   ./build_and_run.sh
   ```

### 以后每次运行：

```bash
./build_and_run.sh
```

---

## 🎯 其他启动方式

### 方式 1：命令行（最快）
```bash
swift run
```

### 方式 2：打包为应用（可双击）
```bash
./package_app.sh
open TTPlayer.app
```

### 方式 3：生成 Xcode 项目（推荐开发）
```bash
swift package generate-xcodeproj
open TTPlayer.xcodeproj
```

---

## ❓ 常见问题

**Q: 为什么要安装 Command Line Tools？**  
A: Swift 编译器需要它才能工作

**Q: 可以不用 Xcode 吗？**  
A: 可以！用命令行就能运行

**Q: 如何生成可双击的应用？**  
A: 运行 `./package_app.sh`

**Q: 编译很慢吗？**  
A: 第一次约 30 秒，之后有缓存很快

---

现在就试试吧！ 🎵
