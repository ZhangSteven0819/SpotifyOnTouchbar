#!/bin/bash
set -euo pipefail

APP_SOURCE="/Applications/Spotify on Touchbar.app"
APP_NAME="Spotify on Touchbar.app"
VOLUME_NAME="Spotify on Touchbar"
RELEASE_NAME="Spotify-on-Touchbar-v1.0.0.dmg"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/release-build"
STAGE_DIR="$BUILD_DIR/stage"
OUTPUT_DMG="$SCRIPT_DIR/$RELEASE_NAME"

rm -rf "$BUILD_DIR"
mkdir -p "$STAGE_DIR"

if [ ! -d "$APP_SOURCE" ]; then
    echo "Missing app bundle: $APP_SOURCE" >&2
    exit 1
fi

ditto "$APP_SOURCE" "$STAGE_DIR/$APP_NAME"
APP_PLIST="$STAGE_DIR/$APP_NAME/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName Spotify on Touchbar" "$APP_PLIST" >/dev/null 2>&1 || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string Spotify on Touchbar" "$APP_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleName Spotify on Touchbar" "$APP_PLIST" >/dev/null 2>&1 || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleName string Spotify on Touchbar" "$APP_PLIST"
cp "$SCRIPT_DIR/Install.command" "$STAGE_DIR/Install.command"
cp "$SCRIPT_DIR/README.md" "$STAGE_DIR/README.md"
cp "$SCRIPT_DIR/README_zh.md" "$STAGE_DIR/README_zh.md"

ln -s /Applications "$STAGE_DIR/Applications"

hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGE_DIR" \
    -ov \
    -format UDZO \
    "$OUTPUT_DMG"

echo "Created: $OUTPUT_DMG"
