#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_SOURCE="$SCRIPT_DIR/release-artifacts/Spotify on Touchbar.app"
PKG_NAME="Spotify-on-Touchbar-v1.0.0.pkg"
BUILD_DIR="$SCRIPT_DIR/release-pkg-build"
ROOT_DIR="$BUILD_DIR/root"
SCRIPTS_DIR="$BUILD_DIR/scripts"
OUTPUT_PKG="$SCRIPT_DIR/$PKG_NAME"

rm -rf "$BUILD_DIR"
mkdir -p "$ROOT_DIR" "$SCRIPTS_DIR"

if [ ! -d "$APP_SOURCE" ]; then
    echo "Missing app bundle: $APP_SOURCE" >&2
    exit 1
fi

ditto "$APP_SOURCE" "$ROOT_DIR/Spotify on Touchbar.app"
cp "$SCRIPT_DIR/installer-scripts/postinstall" "$SCRIPTS_DIR/postinstall"
chmod +x "$SCRIPTS_DIR/postinstall"

pkgbuild \
    --root "$ROOT_DIR" \
    --scripts "$SCRIPTS_DIR" \
    --identifier "com.touchbarlyrics.app.installer" \
    --version "1.0.0" \
    --install-location "/Applications" \
    "$OUTPUT_PKG"

echo "Created: $OUTPUT_PKG"
