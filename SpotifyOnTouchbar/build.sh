#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
SOURCES="$SCRIPT_DIR/Sources"

echo "🔨 Spotify on Touchbar Build Script"
echo "==============================="

mkdir -p "$BUILD_DIR"

echo ""
echo "📦 编译中..."

swiftc \
    -sdk $(xcrun --show-sdk-path) \
    -target arm64-apple-macos13.0 \
    -framework Cocoa \
    -I "$SOURCES" \
    "$SOURCES/DFRPrivate/DFRPrivateLoader.m" \
    "$SOURCES/DFRPrivate/DFRPrivateWrapper.m" \
    "$SOURCES/main.swift" \
    "$SOURCES/AppDelegate.swift" \
    "$SOURCES/AppLocalization.swift" \
    "$SOURCES/SpotifyController.swift" \
    "$SOURCES/TouchBarController.swift" \
    "$SOURCES/LRCParser.swift" \
    "$SOURCES/LyricsCacheStore.swift" \
    -o "$BUILD_DIR/SpotifyLyrics"

echo "✅ 编译成功"
echo ""
echo "🚀 运行应用："
echo "   $BUILD_DIR/SpotifyLyrics"
echo ""
echo "💡 首次运行后，点击 Touch Bar 上的 🎵 图标或菜单栏 '显示 Touch Bar 歌词'"
