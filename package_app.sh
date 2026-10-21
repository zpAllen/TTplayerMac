#!/bin/bash

# 打包为 macOS 应用（含图标、Info.plist、签名）
# 用法：
#   ./package_app.sh                    # Apple 芯片 release 包
#   ./package_app.sh --universal        # 通用包（Intel + Apple 芯片）
#   ./package_app.sh --binary <路径>    # 用已编译好的二进制打包（跳过编译）

set -e
cd "$(dirname "$0")"

UNIVERSAL=0
BINARY=""
while [ $# -gt 0 ]; do
    case "$1" in
        --universal) UNIVERSAL=1; shift ;;
        --binary) BINARY="$2"; shift 2 ;;
        *) echo "❌ 未知参数: $1"; exit 1 ;;
    esac
done

if [ -z "$BINARY" ]; then
    echo "🔨 编译中..."
    if [ "$UNIVERSAL" -eq 1 ]; then
        swift build -c release --arch arm64 --arch x86_64
        BINARY=".build/apple-macosx/release/TTPlayer"
    else
        swift build -c release
        BINARY=".build/arm64-apple-macosx/release/TTPlayer"
    fi
fi
[ -f "$BINARY" ] || { echo "❌ 找不到二进制: $BINARY"; exit 1; }

echo "📦 组装 TTPlayer.app..."
APP="TTPlayer.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BINARY" "$APP/Contents/MacOS/TTPlayer"
chmod +x "$APP/Contents/MacOS/TTPlayer"

# 图标
if [ -f Packaging/AppIcon.icns ]; then
    cp Packaging/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
else
    echo "⚠️  没有 Packaging/AppIcon.icns（先运行 ./Packaging/make_icns.sh）"
fi

# 原版默认皮肤（随 app 分发）
if [ -d TTPlayerv5.7.9 ]; then
    cp -R TTPlayerv5.7.9 "$APP/Contents/Resources/"
else
    echo "⚠️  没有 TTPlayerv5.7.9/ttpres.dll（app 将退回自绘界面）"
fi

cat > "$APP/Contents/Info.plist" << 'PLIST'
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
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.music</string>
</dict>
</plist>
PLIST

# 签名（默认临时签名；可用 CODESIGN_IDENTITY 指定开发者证书）
IDENTITY="${CODESIGN_IDENTITY:--}"
echo "✍️  签名（$IDENTITY）..."
codesign --force --sign "$IDENTITY" "$APP"

echo ""
echo "✅ 打包完成：$(pwd)/$APP"
echo "   本地运行：open $APP"
