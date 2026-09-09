# WinToMacCursor 🖱️✨

<p align="center">
  <img src="Resources/AppIcon.png" width="128" height="128" alt="WinToMacCursor 图标">
</p>

<p align="center">
  <b>专为 macOS 打造的原生 SwiftUI 菜单栏常驻应用，支持将 Windows 鼠标光标（.cur / .ani）一键转换为 macOS 原生主题，具备动画回放、菜单栏秒级切换与会话级系统指针注入功能。</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/版本-2.0.0-blue.svg" alt="版本 2.0.0">
  <img src="https://img.shields.io/badge/平台-macOS%2013.0%2B-lightgrey.svg" alt="平台 macOS 13+">
  <img src="https://img.shields.io/badge/Swift-5.9%2B-orange.svg" alt="Swift 5.9+">
  <img src="https://img.shields.io/badge/协议-MIT-green.svg" alt="协议 MIT">
</p>

<p align="center">
  <a href="README.md">English</a> | <b>简体中文</b>
</p>

---

## 🚀 v2.0.0 全新特性

- 🏗️ **全面重构为原生 SwiftUI App 架构**：告别传统命令行与脚本编译体系，迁移至纯正的 Xcode `@main WinToMacCursorApp: App` 架构。
- 🎛️ **现代 MenuBarExtra 托盘常驻**：实时系统状态指示灯、启用/暂停快捷开关（⌘⇧S）、光标方案快捷子菜单与一键恢复默认——完全常驻在 macOS 顶部状态栏。
- ⚙️ **标准 macOS 设置窗口（Settings Scene）**：支持快捷键 ⌘, 呼出，原生接入 **SMAppService 开机自动启动**、程序坞（Dock）图标隐藏/常驻模式切换、双语偏好设置与退出还原选项。
- 🛡️ **底层生命周期安全守卫**：结合 `NSApplicationDelegateAdaptor`，在应用关闭或退出时确保安全卸载注入并自动恢复系统默认光标，防止指针状态丢失。
- 🎨 **全新多分辨率高清图标**：内嵌精致的拟物化 macOS 风格光标图标，支持 Asset Catalog 与 ICNS 双重保底解析。

---

## ✨ 核心特性

- 📥 **全面的 Windows 光标解析**：原生二进制解码静态 `.cur` 文件、多帧动态 `.ani`（RIFF/ACON 格式，精准时间片还原）以及 `install.inf` 主题配置文件。
- 📦 **macOS 标准 `.cape` 主题导出**：全自动合成 1x 与 2x Retina 视网膜级垂直雪碧图（Vertical Sprite Sheet），完美适配 Mousecape 生态。
- 🎬 **实时动画检视器**：逐帧高精度回放控制（支持 0.25x ~ 3.0x 倍速调节、逐帧步进、点击热点红十字准星对准指示）。
- 🎯 **交互式试用画板 (Cursor Playground)**：鼠标移入画布即时化身所选动态光标，具备点击波纹特效与热点对齐手感测试。
- ⚡ **即时系统级光标注入**：基于 macOS 底层 SkyLight CGS 私有 API 与 `CoreCursorUnregisterAll`，在当前用户会话中全局秒级生效，无需守护进程或重启电脑。
- 🚀 **菜单栏静默运行**：作为 UIElement 代理程序运行，不占用 Dock 栏与 Cmd+Tab 任务切换器，桌面干练清爽。
- ↺ **正版苹果原生光标一键恢复**：内置官方全套 21 项系统原生光标资产（`DefaultMacCursor.cape`），随时一键瞬时恢复默认。
- 🌐 **多语言国际化 (i18n)**：原生支持简体中文与 English，跟随 macOS 系统语言自动适配，亦支持在设置面板中手动指定。
- 💾 **本地方案库持久化存储**：方案数据持久保存在 Application Support 目录中，随时管理、导入与删除。

---

## 🖥️ 架构概览

```
WinToMacCursor (v2.0.0 架构)
├── WinToMacCursorApp.swift         # SwiftUI App 入口 + MenuBarExtra 托盘 + 生命周期守卫
├── Views/
│   ├── ContentView.swift           # 主窗口 3 列式 NavigationSplitView 导航与工具栏
│   ├── CursorDetailView.swift      # 放大检视面板与动画胶片序列条
│   ├── CursorItemView.swift        # 方案光标项卡片与动态微缩预览
│   ├── CursorPlaygroundView.swift   # 交互式点击与准星对齐画板
│   └── SettingsView.swift          # 标准偏好设置窗口 (开机启动, Dock 策略, 语言)
├── Services/
│   ├── SystemCursorManager.swift   # SkyLight CGS & CoreCursor 动态光标注入引擎
│   ├── SchemeLibraryManager.swift  # 方案发现与本地持久化方案库管理
│   ├── SchemeLoader.swift          # 文件夹与 INF 解析加载器
│   └── AppStateManager.swift       # Dock 激活策略与全局偏好状态
├── Parsers/
│   ├── WindowsCursorParser.swift   # 二进制 .cur 与 .ani (RIFF/ACON) 解析器
│   └── INFParser.swift             # install.inf 主题脚本解析器
├── Generators/
│   └── CapeGenerator.swift         # 垂直雪碧图与 .cape 格式生成器
└── Resources/
    ├── AppIcon.icns                # 多分辨率原生 macOS 图标包
    └── DefaultMacCursor.cape       # Apple 原生默认光标资源包
```

---

## 🛠️ 系统要求与编译运行

### 系统要求
- macOS 13.0 (Ventura) 及更高版本
- Xcode 15.0 及更高版本

### 使用 Xcode 编译
1. 克隆本仓库：
   ```bash
   git clone https://github.com/HongYuehao123/MacOS-Cursor-From-Win.git
   cd MacOS-Cursor-From-Win
   ```
2. 双击打开 `WinToMacCursor.xcodeproj`。
3. 按下快捷键 **⌘R** 即可一键编译并启动运行。

### 使用命令行编译
```bash
xcodebuild -project WinToMacCursor.xcodeproj -scheme WinToMacCursor -configuration Release build
```
编译产物 `WinToMacCursor.app` 将输出至构建目录中。

---

## 📄 开源协议

本项目采用 [MIT License](LICENSE) 开源协议。
