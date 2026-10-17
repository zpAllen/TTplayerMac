#!/bin/bash

# TTPlayer 快速启动脚本

echo "🎵 TTPlayer for macOS"
echo "===================="
echo ""

# 检查是否已安装 Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ 错误: 未安装 Xcode 或 Xcode Command Line Tools"
    echo "请先安装: xcode-select --install"
    exit 1
fi

echo "📦 正在构建项目..."
swift build

if [ $? -eq 0 ]; then
    echo "✅ 构建成功！"
    echo ""
    echo "🚀 启动 TTPlayer..."
    .build/debug/TTPlayer
else
    echo "❌ 构建失败，请检查错误信息"
    exit 1
fi
