#!/bin/bash

# 打 DMG 安装包
# 用法：
#   ./make_dmg.sh                    # Apple 芯片
#   ./make_dmg.sh --universal        # 通用包（Intel + Apple 芯片）
# 产物：TTPlayer-1.0.0.dmg（含 TTPlayer.app 和 Applications 快捷方式）

set -e
cd "$(dirname "$0")"

VERSION="1.0.0"
VOLUME="千千静听"
DMG="TTPlayer-${VERSION}.dmg"

# 1. 编译并组装 .app
./package_app.sh "$@"

# 2. 组装 DMG 内容
STAGE=".dmg_stage"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R TTPlayer.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"

# 3. 创建 DMG
rm -f "$DMG"
echo "💿 创建 $DMG ..."
hdiutil create -volname "$VOLUME" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

# 4. 挂载后用 Finder 排版（图标位置）。需要「控制 Finder」的自动化权限，
#    第一次运行会弹系统授权框；失败或无权挂载就保留默认布局，不影响 DMG。
if hdiutil attach "$DMG" -readwrite -noverify -noautoopen >/dev/null 2>&1; then
    MOUNT="/Volumes/$VOLUME"
    osascript << OSA 2>/dev/null || echo "⚠️  跳过 Finder 排版（未授权自动化）"
tell application "Finder"
    tell disk "$VOLUME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 100, 920, 480}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set position of item "TTPlayer.app" of container window to {120, 160}
        set position of item "Applications" of container window to {400, 160}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
OSA
    hdiutil detach "$MOUNT" >/dev/null
else
    echo "⚠️  跳过 Finder 排版（挂载失败，DMG 本身没问题）"
fi

echo ""
echo "✅ DMG 打包完成：$(pwd)/$DMG"
echo "   对方打开 DMG 后，把 TTPlayer 拖进 Applications 即可。"
echo "   没有开发者证书时是临时签名，首次打开需要右键「打开」。"
