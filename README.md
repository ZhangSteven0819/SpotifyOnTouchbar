# 🎵 Spotify on Touchbar

> 中文指南请看 [README_zh.md](./README_zh.md)

> Display real-time lyrics from Spotify on your MacBook Pro's Touch Bar.

[![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue)](https://www.apple.com/macos)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Touch%20Bar-FF2D55?style=flat-square)](#)

## 🎬 Effect Showcase

![Effect Showcase](https://raw.githubusercontent.com/ZhangSteven0819/SpotifyOnTouchbar/main/assets/effect-showcase.jpg)

## ✨ Features

- **Touch Bar Lyrics** — Displays current playing lyrics on Touch Bar with active-line progress
- **Spotify Auto Sync** — Starts and stops with Spotify, keeps lyrics synced in the background
- **Language Menu** — Follows the system language by default, with popular languages available
- **LRC Sync** — LRC format time-synced lyrics support
- **Menu Bar App** — Runs in the background, no Dock icon

## 📦 Download

**Download the latest release DMG, then drag the app into Applications.**

> ⚠️ **Note:** This release is for Touch Bar MacBook Pro models. The app is built as an Apple Silicon release.

## 🚀 Installation

1. Download the release DMG and open it
2. Drag **Spotify on Touchbar.app** into the `Applications` folder shortcut
3. Eject the DMG
4. Launch **Spotify on Touchbar** from Applications

The app follows Spotify's open/close state in the background once launched.

## ⚠️ First Run Permissions

On first launch, macOS will request two permissions:

1. **Accessibility** — Required to control Spotify
2. **AppleScript / Automation** — Required to read Spotify playback info

Go to **System Settings → Privacy & Security → Accessibility** and add Spotify on Touchbar if macOS asks for it.

## 📖 Usage

1. Make sure Spotify is playing a song
2. Click the 🎵 icon in the menu bar to manage the app
3. Lyrics appear on the Touch Bar automatically
4. Use the menu bar to change language if needed

## 🔧 Build from Source

```bash
cd SpotifyOnTouchbar
./build.sh
open build/SpotifyLyrics
```

### Requirements

- macOS 13.0 (Ventura) or later
- Xcode Command Line Tools
- Apple Silicon Mac (M1 / M2 / M3)
- Spotify desktop client (not the web player)

## 🛠 Technical Details

- **Spotify Integration**: AppleScript for reading current track info (name, artist, position)
- **Lyrics Source**: [LRCLib.net](https://lrclib.net) API (free open-source lyrics database)
- **Lyrics Format**: LRC time-synced lyrics with `[mm:ss.xx]` timestamps
- **Sync Mechanism**: Polls Spotify playback position continuously in the background and matches against LRC timeline

## ⚠️ Known Limitations

- Touch Bar feature requires MacBook Pro with Touch Bar (2016–2020)
- Lyrics depend on LRCLib.net database — some songs may not have lyrics
- Spotify must be the desktop client (not web player)
- Apple Silicon (M1/M2/M3) Macs are supported

## 📄 License

MIT License — see [LICENSE](LICENSE)
