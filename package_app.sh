#!/bin/bash

# 打包为 macOS 应用

echo "📦 开始打包 TTPlayer.app..."

# 1. 编译 release 版本
echo "🔨 编译中..."
swift build -c release

if [ $? -ne 0 ]; then
    echo "❌ 编译失败"
    exit 1
fi

# 2. 创建应用包结构
echo "📁 创建应用包结构..."
rm -rf TTPlayer.app
mkdir -p TTPlayer.app/Contents/MacOS
mkdir -p TTPlayer.app/Contents/Resources

# 3. 复制可执行文件
echo "📋 复制文件..."
cp .build/release/TTPlayer TTPlayer.app/Contents/MacOS/

# 4. 创建 Info.plist
cat > TTPlayer.app/Contents/Info.plist << 'PLIST'
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
    <key>CFBundleDisplayName</key>
    <string>千千静听</string>
    <key>CFBundleVersion</key>
    <string>0.1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.music</string>
</dict>
</plist>
PLIST

# 5. 设置权限
chmod +x TTPlayer.app/Contents/MacOS/TTPlayer

echo "✅ 打包完成！"
echo ""
echo "🚀 现在可以运行："
echo "   open TTPlayer.app"
echo ""
echo "📍 应用位置："
echo "   $(pwd)/TTPlayer.app"
