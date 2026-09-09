# WinToMacCursor 🖱️✨

<p align="center">
  <img src="WinToMacCursor/AppIcon.png" width="128" height="128" alt="WinToMacCursor Icon">
</p>

<p align="center">
  <b>A modern native macOS menu bar application built with SwiftUI to convert Windows cursor themes (.cur / .ani) into native macOS themes with real-time animation preview, menu bar quick-switching, and deep session-level system pointer injection.</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-2.0.0-blue.svg" alt="Version 2.0.0">
  <img src="https://img.shields.io/badge/platform-macOS%2013.0%2B-lightgrey.svg" alt="Platform macOS 13+">
  <img src="https://img.shields.io/badge/swift-5.9%2B-orange.svg" alt="Swift 5.9+">
  <img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License MIT">
</p>

<p align="center">
  <b>English</b> | <a href="README_cn.md">简体中文</a>
</p>

---

## 🚀 What's New in v2.0.0

- 🏗️ **Re-architected as a Native SwiftUI App**: Migrated from legacy command-line / SPM structures to a pure Xcode `@main WinToMacCursorApp: App` architecture.
- 🎛️ **Modern MenuBarExtra Integration**: Live system status indicator, quick-toggle switch (⌘⇧S), submenus for scheme switching, and system default restoration—all directly from the macOS status bar.
- ⚙️ **Standard macOS Settings Window**: Dedicated Preferences (`Settings` Scene via ⌘,) featuring **Launch at Login** (`SMAppService`), Dock icon visibility toggling, language switcher, and exit behaviors.
- 🛡️ **Fail-Safe Lifecycle Management**: Leverages `NSApplicationDelegateAdaptor` to guarantee teardown and automatic cursor restoration on termination, preventing any pointer anomalies.
- 🎨 **Polished App Icon**: Includes high-resolution multi-scale Retina icon assets embedded via both Asset Catalog and native ICNS formats.

---

## ✨ Key Features

- 📥 **Comprehensive Windows Cursor Parsing**: Native binary decoding of static `.cur` files, multi-frame animated `.ani` (RIFF/ACON format) files, and `install.inf` scheme registry scripts.
- 📦 **macOS Standard `.cape` Theme Export**: Automatically compiles vertical sprite sheets in both 1x and 2x Retina resolutions, fully compatible with the macOS Mousecape ecosystem.
- 🎬 **Real-Time Animation Inspector**: Frame-by-frame preview with playback speed adjustment (0.25x – 3.0x), stepping controls, and interactive click hotspot (crosshair) indicator.
- 🎯 **Interactive Cursor Playground**: A live testing canvas where hovering immediately transforms your mouse into the selected animated cursor, complete with click ripple effects and alignment feedback.
- ⚡ **Instant System-Level Cursor Injection**: Utilizes low-level macOS SkyLight CGS APIs and `CoreCursorUnregisterAll` to inject custom pointers system-wide without requiring reboots or helper daemon installations.
- 🚀 **MenuBar Tray Companion**: Runs silently as an agent (UIElement) in your macOS menu bar without cluttering your Dock or App Switcher (Cmd+Tab).
- ↺ **Apple Native Default Cursor Restoration**: Bundles authentic macOS default cursor profiles (`DefaultMacCursor.cape`) to cleanly and safely revert changes at any time.
- 🌐 **Multilingual Localization (i18n)**: Out-of-the-box support for English and Simplified Chinese (zh-Hans), adhering to system locale with manual override options.
- 💾 **Persistent Scheme Library**: Store, organize, and manage multiple imported cursor schemes directly in your user Application Support directory.

---

## 🖥️ Architecture Overview

```
WinToMacCursor (v2.0.0 Architecture)
├── WinToMacCursorApp.swift         # SwiftUI App Entry + MenuBarExtra + Lifecycle Guard
├── Views/
│   ├── ContentView.swift           # Primary 3-column NavigationSplitView & Toolbar
│   ├── CursorDetailView.swift      # Magnified Inspector & Animation Filmstrip
│   ├── CursorItemView.swift        # Sidebar Scheme Item Card & Live Thumbnail
│   ├── CursorPlaygroundView.swift   # Interactive Click & Alignment Testbed
│   └── SettingsView.swift          # Standard Preferences (Launch at Login, Dock, i18n)
├── Services/
│   ├── SystemCursorManager.swift   # SkyLight CGS & CoreCursor Pointer Injection Engine
│   ├── SchemeLibraryManager.swift  # Scheme Discovery & Persistent Library Store
│   ├── SchemeLoader.swift          # Directory & INF Scheme Loader
│   └── AppStateManager.swift       # Dock Policy & User Preferences State
├── Parsers/
│   ├── WindowsCursorParser.swift   # Binary .cur & .ani (RIFF/ACON) Decoders
│   └── INFParser.swift             # install.inf Theme Script Parser
├── Generators/
│   └── CapeGenerator.swift         # Vertical Sprite Sheet & .cape Theme Generator
└── Resources/
    ├── AppIcon.icns                # Multi-resolution macOS App Icon
    └── DefaultMacCursor.cape       # Authentic Apple System Cursor Assets
```

---

## 🛠️ Requirements & Building

### Requirements
- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later

### Building with Xcode
1. Clone this repository:
   ```bash
   git clone https://github.com/HongYuehao123/MacOS-Cursor-From-Win.git
   cd MacOS-Cursor-From-Win
   ```
2. Open `WinToMacCursor.xcodeproj` in Xcode.
3. Press **⌘R** to build and run the application.

### Building via Command Line
```bash
xcodebuild -project WinToMacCursor.xcodeproj -scheme WinToMacCursor -configuration Release build
```
The compiled `WinToMacCursor.app` will be located in the build output directory.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
