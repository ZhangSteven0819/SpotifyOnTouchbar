#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_SOURCE="$SCRIPT_DIR/release-artifacts/Spotify on Touchbar.app"
APP_NAME="Spotify on Touchbar.app"
VOLUME_NAME="Spotify on Touchbar"
RELEASE_NAME="Spotify-on-Touchbar-v1.0.0.dmg"
BUILD_DIR="$SCRIPT_DIR/release-build"
STAGE_DIR="$BUILD_DIR/stage"
OUTPUT_DMG="$SCRIPT_DIR/$RELEASE_NAME"

rm -rf "$BUILD_DIR"
mkdir -p "$STAGE_DIR"
rm -f "$OUTPUT_DMG"

if [ ! -d "$APP_SOURCE" ]; then
    echo "Missing app bundle: $APP_SOURCE" >&2
    exit 1
fi

ditto "$APP_SOURCE" "$STAGE_DIR/$APP_NAME"
xattr -cr "$STAGE_DIR/$APP_NAME" || true
codesign --remove-signature "$STAGE_DIR/$APP_NAME" >/dev/null 2>&1 || true
codesign --force --deep --sign - --timestamp=none "$STAGE_DIR/$APP_NAME"
codesign --verify --deep --strict --verbose=2 "$STAGE_DIR/$APP_NAME"
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
