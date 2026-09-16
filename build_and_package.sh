#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$SCRIPT_DIR/release-artifacts/Spotify on Touchbar.app"
BIN_TARGET="$APP_DIR/Contents/MacOS/Spotify on Touchbar"
SOURCES="$SCRIPT_DIR/SpotifyOnTouchbar/Sources"

echo "=========================================="
echo "📦 1. 编译最新的 Spotify on Touchbar 二进制"
echo "=========================================="

SWIFTC="/Library/Developer/CommandLineTools/usr/bin/swiftc"
SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"

"$SWIFTC" \
    -sdk "$SDK" \
    -target arm64-apple-macos13.0 \
    -framework Cocoa \
    -I "$SOURCES" \
    "$SOURCES/DFRPrivate/DFRPrivateLoader.m" \
    "$SOURCES/DFRPrivate/DFRPrivateWrapper.m" \
    "$SOURCES/main.swift" \
    "$SOURCES/AppDelegate.swift" \
    "$SOURCES/AppLocalization.swift" \
    "$SOURCES/LaunchAgentManager.swift" \
    "$SOURCES/SpotifyController.swift" \
    "$SOURCES/TouchBarController.swift" \
    "$SOURCES/LRCParser.swift" \
    "$SOURCES/LyricsCacheStore.swift" \
    -o "$BIN_TARGET"

chmod +x "$BIN_TARGET"
echo "✅ 二进制编译成功: $BIN_TARGET"

echo "=========================================="
echo "🔏 2. 重新签名并清理属性"
echo "=========================================="
xattr -cr "$APP_DIR" || true
codesign --remove-signature "$APP_DIR" >/dev/null 2>&1 || true
codesign --force --deep --sign - --timestamp=none "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

echo "=========================================="
echo "💿 3. 构建发布 DMG"
echo "=========================================="
"$SCRIPT_DIR/make_release_dmg.sh"

echo "=========================================="
echo "📦 4. 同步更新根目录发布产物"
echo "=========================================="
ROOT_DIR="/Users/steven/Documents/Codex/2026-06-10/spotify-touch-bar"
cp "$SCRIPT_DIR/Spotify-on-Touchbar-v1.0.0.dmg" "$ROOT_DIR/Spotify-on-Touchbar-v1.0.0.dmg"
cd "$ROOT_DIR"
rm -f Spotify-on-Touchbar-v1.0.0.zip
ditto -c -k --keepParent "$APP_DIR" Spotify-on-Touchbar-v1.0.0.zip

echo "🎉 全部构建完成！"
echo "产物路径："
echo "DMG: $ROOT_DIR/Spotify-on-Touchbar-v1.0.0.dmg"
echo "ZIP: $ROOT_DIR/Spotify-on-Touchbar-v1.0.0.zip"
