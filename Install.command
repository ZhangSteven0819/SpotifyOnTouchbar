#!/bin/bash
set -euo pipefail

APP_NAME="Spotify on Touchbar.app"
APP_BUNDLE_ID="com.shiyangzheng.touchbarlyrics"
INSTALL_DIR="/Applications"
USER_APP_DIR="$HOME/Applications"
INSTALL_ROOT="$HOME/Library/Application Support/Spotify on Touchbar"
WATCH_SCRIPT="$INSTALL_ROOT/spotify-watch.sh"
LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
LAUNCH_AGENT_PLIST="$LAUNCH_AGENT_DIR/com.shiyangzheng.touchbarlyrics.spotifywatcher.plist"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_APP=""

for candidate in \
    "$SCRIPT_DIR/$APP_NAME" \
    "$SCRIPT_DIR/build/$APP_NAME" \
    "$SCRIPT_DIR/SpotifyOnTouchbar/build/SpotifyLyrics"; do
    if [ -e "$candidate" ]; then
        SOURCE_APP="$candidate"
        break
    fi
done

if [ -z "$SOURCE_APP" ]; then
    osascript -e 'display dialog "没有找到可安装的 Spotify on Touchbar.app。请把安装器和应用程序放在同一个文件夹里再试一次。" buttons {"好"} default button "好" with icon stop'
    exit 1
fi

DEST_APP="$INSTALL_DIR/$APP_NAME"
if [ ! -w "$INSTALL_DIR" ]; then
    mkdir -p "$USER_APP_DIR"
    DEST_APP="$USER_APP_DIR/$APP_NAME"
fi

rm -rf "$DEST_APP"
ditto "$SOURCE_APP" "$DEST_APP"
chmod +x "$DEST_APP/Contents/MacOS/"*

APP_PLIST="$DEST_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName Spotify on Touchbar" "$APP_PLIST" >/dev/null 2>&1 || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string Spotify on Touchbar" "$APP_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleName Spotify on Touchbar" "$APP_PLIST" >/dev/null 2>&1 || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleName string Spotify on Touchbar" "$APP_PLIST"

mkdir -p "$INSTALL_ROOT" "$LAUNCH_AGENT_DIR"

cat > "$WATCH_SCRIPT" <<'EOF'
#!/bin/bash
set -euo pipefail

APP_BUNDLE_ID="com.shiyangzheng.touchbarlyrics"
APP_NAME="Spotify on Touchbar"
APP_PATH="__APP_PATH__"
CHECK_INTERVAL=4

spotify_running() {
    pgrep -x "Spotify" >/dev/null 2>&1
}

app_running() {
    pgrep -x "$APP_NAME" >/dev/null 2>&1
}

launch_app() {
    open -gj "$APP_PATH"
}

quit_app() {
    /usr/bin/osascript -e "tell application id \"$APP_BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
}

while true; do
    if spotify_running; then
        if ! app_running; then
            launch_app
        fi
    else
        if app_running; then
            quit_app
        fi
    fi
    sleep "$CHECK_INTERVAL"
done
EOF

perl -0pi -e "s|__APP_PATH__|$DEST_APP|g" "$WATCH_SCRIPT"

chmod +x "$WATCH_SCRIPT"

cat > "$LAUNCH_AGENT_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.shiyangzheng.touchbarlyrics.spotifywatcher</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$WATCH_SCRIPT</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF

launchctl bootout "gui/$UID" "$LAUNCH_AGENT_PLIST" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$UID" "$LAUNCH_AGENT_PLIST" >/dev/null 2>&1 || true
launchctl enable "gui/$UID/com.shiyangzheng.touchbarlyrics.spotifywatcher" >/dev/null 2>&1 || true

if pgrep -x "Spotify" >/dev/null 2>&1; then
    open -gj "$DEST_APP"
fi

osascript <<EOF
display dialog "安装成功。\n\nSpotify on Touchbar 已安装到：\n$DEST_APP\n\n它会：\n• 随 Spotify 打开/关闭自动运行\n• 默认识别系统语言，识别不到时使用英语\n• 你也可以在菜单栏里手动切换热门语言" buttons {"好"} default button "好" with icon note
EOF
