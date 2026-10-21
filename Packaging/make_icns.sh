#!/bin/bash
# 从 1024 母版生成 AppIcon.icns
# 用法：./Packaging/make_icns.sh

set -e
cd "$(dirname "$0")/.."

MASTER="Packaging/AppIcon_1024.png"
[ -f "$MASTER" ] || { echo "❌ 先运行 swift Packaging/make_icon.swift"; exit 1; }

ICONSET="Packaging/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

sips -z 16 16     "$MASTER" --out "$ICONSET/icon_16x16.png"       >/dev/null
sips -z 32 32     "$MASTER" --out "$ICONSET/icon_16x16@2x.png"    >/dev/null
sips -z 32 32     "$MASTER" --out "$ICONSET/icon_32x32.png"       >/dev/null
sips -z 64 64     "$MASTER" --out "$ICONSET/icon_32x32@2x.png"    >/dev/null
sips -z 128 128   "$MASTER" --out "$ICONSET/icon_128x128.png"     >/dev/null
sips -z 256 256   "$MASTER" --out "$ICONSET/icon_128x128@2x.png"  >/dev/null
sips -z 256 256   "$MASTER" --out "$ICONSET/icon_256x256.png"     >/dev/null
sips -z 512 512   "$MASTER" --out "$ICONSET/icon_256x256@2x.png"  >/dev/null
sips -z 512 512   "$MASTER" --out "$ICONSET/icon_512x512.png"     >/dev/null
cp "$MASTER" "$ICONSET/icon_512x512@2x.png"

iconutil -c icns "$ICONSET" -o Packaging/AppIcon.icns
rm -rf "$ICONSET"
echo "✅ Packaging/AppIcon.icns"
