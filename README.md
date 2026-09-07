# WinToMacCursor 🖱️✨

<p align="center">
  <img src="Resources/AppIcon.png" width="128" height="128" alt="WinToMacCursor Icon">
</p>

<p align="center">
  <b>Convert Windows cursor themes (.cur / .ani) into native macOS themes with real-time animation playback, Menu Bar quick-switching, and session-level system cursor replacement.</b>
</p>

<p align="center">
  <b>English</b> | <a href="README_cn.md">简体中文</a>
</p>

---

## ✨ Key Features

- 📥 **Comprehensive Windows Cursor Parsing**: Native decoding of static `.cur` files, animated `.ani` files (RIFF/ACON format with multi-frame precision decoding), and `install.inf` theme configuration scripts.
- 📦 **macOS Standard `.cape` Theme Export**: Automatically stitches vertical sprite sheets in both 1x and 2x Retina resolutions, fully compatible with the macOS Mousecape specification.
- 🎬 **Real-Time Animation Inspector**: High-precision frame-by-frame preview with adjustable speed (0.25x – 3.0x), step-forward/backward controls, and interactive red crosshair hotspot indicator.
- 🎯 **Interactive Cursor Playground**: A dedicated sandbox where hovering instantly renders your custom animated cursor with click ripple feedback and alignment testing.
- ⚡ **One-Click System Cursor Application**: Powered by macOS low-level SkyLight CGS APIs to immediately update global system pointers without requiring third-party tools or system reboot.
- 🚀 **Menu Bar Quick Switcher**: Always accessible from the macOS menu bar. Easily switch between all imported cursor schemes or restore defaults in seconds.
- ↺ **Authentic Apple Default Cursor Restoration**: Ships with a complete bundle of 21 authentic macOS default cursor assets (`DefaultMacCursor.cape`) to instantly restore system cursors safely and cleanly.
- 🌐 **Multilingual Localization (i18n)**: Full support for both English and Simplified Chinese (zh-Hans). Automatically follows macOS system language and allows in-app language switching.
- 💾 **Persistent Theme Library**: Import custom themes or individual cursor files with persistent storage in your Application Support directory.

---

## 🛠️ Requirements & Building

### Requirements
- macOS 13.0 (Ventura) or later
- Xcode Command Line Tools (`swiftc`)

### Build from Source
Clone this repository and run the build script:
```bash
bash scripts/build_app.sh
```
The compiled bundle will be available at `dist/WinToMacCursor.app`.

Launch the application:
```bash
open "dist/WinToMacCursor.app"
```

---

## 📄 License

MIT License.
