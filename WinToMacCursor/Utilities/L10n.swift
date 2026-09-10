import AppKit
import Combine
import Foundation
import SwiftUI

public enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case chinese = "zh"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system:
            return LanguageManager.shared.effectiveLanguageIsChinese ? "跟随系统 (Follow System)" : "Follow System (跟随系统)"
        case .english:
            return "English"
        case .chinese:
            return "简体中文"
        }
    }
}

public final class LanguageManager: ObservableObject {
    public static let shared = LanguageManager()

    @AppStorage("WinToMacCursor_SelectedLanguage")
    public var selectedLanguageRaw: String = AppLanguage.system.rawValue {
        didSet {
            objectWillChange.send()
            updateAllWindowsTitle()
        }
    }

    public var selectedLanguage: AppLanguage {
        get { AppLanguage(rawValue: selectedLanguageRaw) ?? .system }
        set {
            selectedLanguageRaw = newValue.rawValue
            objectWillChange.send()
            updateAllWindowsTitle()
        }
    }

    public var effectiveLanguageIsChinese: Bool {
        switch selectedLanguage {
        case .chinese:
            return true
        case .english:
            return false
        case .system:
            let preferred = Locale.preferredLanguages.first?.lowercased() ?? ""
            return preferred.hasPrefix("zh")
        }
    }

    public func updateAllWindowsTitle() {
        DispatchQueue.main.async {
            let title = L10n.tr("app_title")
            for window in NSApp.windows {
                let className = String(describing: type(of: window))
                if !className.contains("StatusBar") && !className.contains("Panel") {
                    window.title = title
                }
            }
        }
    }

    private init() {}
}

public struct L10n {
    public static func tr(_ key: String, _ args: CVarArg...) -> String {
        let isZh = LanguageManager.shared.effectiveLanguageIsChinese
        let formatString = isZh ? (zhStrings[key] ?? key) : (enStrings[key] ?? key)
        if args.isEmpty {
            return formatString
        } else {
            return String(format: formatString, arguments: args)
        }
    }

    // Fallback translation tables
    private static let enStrings: [String: String] = [
        "app_title": "WinToMacCursor",

        // Sidebar
        "sidebar_section_title": "Cursor Schemes",
        "scheme_items_count": "%d cursors",
        "delete_scheme": "Delete from Library",
        "delete_scheme_toast": "Removed scheme '%@' from library",
        "import_button": "Import Folder / .cur / .ani...",
        "status_custom_active": "Status: Custom cursor active",
        "status_system_default": "Status: macOS default cursor",
        "status_applied_scheme": "Applied: %@",
        "status_menu_bar_hint": "Quick switch available in Menu Bar",

        // Cursor List
        "animated_scheme_badge": "Animated ANI Scheme",
        "static_scheme_badge": "Static CUR Scheme",
        "scheme_summary": "Contains %d cursors, mapped to macOS core pointer roles",
        "no_scheme_selected": "No cursor scheme selected",
        "select_cursor_prompt": "Select a cursor from the left list to preview and test",

        // Toolbar
        "restore_on_quit": "Restore default on quit",
        "restore_on_quit_help": "Automatically restores macOS default cursor when app terminates",
        "btn_apply": "Apply",
        "btn_apply_help": "Apply current scheme to macOS system cursor",
        "btn_restore": "Restore Defaults",
        "btn_restore_help": "Restore macOS native default cursor",
        "btn_export_cape": "Export .cape",
        "btn_export_cape_help": "Export as macOS Mousecape theme package",
        "btn_export_assets": "Export Assets",
        "btn_export_assets_help": "Export cursor PNG images and animation frames",
        "language_menu": "Language",

        // Actions & Dialogs
        "open_panel_message": "Select folder or files containing Windows cursors (.cur / .ani)",
        "import_success_toast": "Successfully imported '%@' (%d cursors)!",
        "import_fail_error": "Import failed: %@",
        "path_not_exist": "The selected path does not exist",
        "apply_success_toast": "Successfully applied cursor! %d/%d system roles activated.",
        "apply_fail_error": "Failed to apply system cursor. You can export .cape to use with Mousecape.",
        "restore_success_toast": "Successfully restored macOS native default cursor!",
        "restore_fail_error": "Failed to restore default cursor. You can reset in System Settings > Accessibility > Display > Pointer.",
        "save_cape_message": "Choose location to save .cape file",
        "export_cape_success_toast": "Exported '%@' successfully! Double-click to use in macOS.",
        "export_cape_fail_error": "Export failed: %@",
        "export_assets_prompt": "Export to this folder",
        "export_assets_message": "Select destination folder for exported image assets",
        "export_assets_success_toast": "Exported assets successfully to '%@'!",
        "export_assets_fail_error": "Export assets failed: %@",
        "cape_err_serialization": "Failed to serialize cursor scheme to .cape property list",
        "cape_err_empty": "Cursor scheme does not contain any cursors to export",

        // Detail View
        "frames_count_badge": "%d frames animation",
        "background_label": "Background",
        "bg_checkerboard": "Checkerboard",
        "bg_light": "White",
        "bg_dark": "Black",
        "show_hotspot_marker": "Show click hotspot (Crosshair)",
        "frame_step_label": "Frame: %d / %d",
        "playback_speed": "Speed: %.1fx",
        "spec_source_file": "Source File:",
        "spec_cursor_size": "Cursor Size:",
        "spec_cursor_size_val": "%d × %d pixels",
        "spec_hotspot": "Hotspot:",
        "spec_hotspot_val": "X: %d, Y: %d",
        "spec_frame_duration": "Frame Duration:",
        "spec_frame_duration_val": "%.3fs (~ %d FPS)",
        "filmstrip_title": "Animation Frames (%d frames)",
        "system_mappings_title": "Mapped macOS System Identifiers (System Mappings)",

        // Playground
        "playground_title": "Interactive Playground",
        "playground_clicks": "Test clicks: %d",
        "playground_hover_hint": "Move mouse here to test the feel and click alignment of [%@]",
        "playground_align_hint": "Click inside this area to test hotspot alignment",

        // Item View
        "badge_animated": "%d frames",
        "badge_static": "Static",
        "item_hotspot": "Hotspot: (%d, %d)",
        "item_size": "Size: %d×%d",

        // Status Bar Menu
        "status_bar_tooltip": "WinToMacCursor - Quick Cursor Switcher",
        "menu_status_custom": "● Current: %@",
        "menu_status_custom_fallback": "Custom Scheme",
        "menu_status_default": "○ Current: macOS Default",
        "menu_schemes_header": "Quick Switch Schemes:",
        "menu_empty_schemes": "  (No schemes yet, open main window to import)",
        "menu_animated_prefix": "✨ [Animated]",
        "menu_static_prefix": "🖱️ [Static]",
        "menu_scheme_item": "%@ %@ (%d cursors)",
        "menu_restore_defaults": "↺ Restore System Defaults",
        "menu_open_main_window": "🪟 Open Main Window...",
        "menu_settings": "⚙️ Settings...",
        "menu_quit": "🚪 Quit WinToMacCursor",

        // Settings Window
        "settings_title": "Settings",
        "settings_general_tab": "General",
        "settings_language_section": "Language",
        "settings_language_label": "App Language:",
        "settings_dock_section": "Menu Bar & Dock",
        "settings_hide_dock_icon": "Hide Dock Icon (Menu Bar Only)",
        "settings_hide_dock_icon_desc": "When enabled, the app runs quietly in the top menu bar without appearing in the Dock or App Switcher (Cmd+Tab).",
        "settings_termination_section": "Quit Behavior",
        "settings_restore_on_quit": "Restore macOS default cursor on quit",
        "settings_restore_on_quit_desc": "Automatically reverts custom cursor modifications back to Apple native defaults when exiting the application.",
        "settings_about_section": "About",
        "settings_version_label": "Version %@ (%@)",
        "settings_about_description": "A native macOS utility to convert and manage Windows .cur and .ani cursor themes.",

        // Roles
        "role_arrow": "Normal Select",
        "role_help": "Help Select",
        "role_working": "Working in Background",
        "role_busy": "Busy / Waiting",
        "role_precision": "Precision Select / Screenshot",
        "role_text": "Text Select (I-Beam)",
        "role_handwriting": "Handwriting",
        "role_unavailable": "Unavailable",
        "role_vertical": "Vertical Resize",
        "role_horizontal": "Horizontal Resize",
        "role_diagonal1": "Diagonal Resize 1",
        "role_diagonal2": "Diagonal Resize 2",
        "role_move": "Move",
        "role_alternate": "Alternate Select",
        "role_link": "Link Select (Hand)",
        "role_person": "Person / Location",
        "role_pin": "Pin / Marker",
        "role_custom": "Custom Cursor"
    ]

    private static let zhStrings: [String: String] = [
        "app_title": "WinToMacCursor",

        // Sidebar
        "sidebar_section_title": "光标方案库 (Themes)",
        "scheme_items_count": "%d 项光标",
        "delete_scheme": "从方案库中删除",
        "delete_scheme_toast": "已从方案库中移除【%@】",
        "import_button": "导入文件夹 / .cur / .ani...",
        "status_custom_active": "当前状态: 自定义光标已生效",
        "status_system_default": "当前状态: 系统默认光标",
        "status_applied_scheme": "已应用: %@",
        "status_menu_bar_hint": "支持在顶部菜单栏快速切换",

        // Cursor List
        "animated_scheme_badge": "动态 ANI 方案",
        "static_scheme_badge": "静态 CUR 方案",
        "scheme_summary": "共包含 %d 种光标，支持适配 macOS 系统核心状态",
        "no_scheme_selected": "暂无选中的光标方案",
        "select_cursor_prompt": "请在左侧列表中选择一个光标进行预览与试用",

        // Toolbar
        "restore_on_quit": "退出时恢复默认",
        "restore_on_quit_help": "完全退出 App 时自动将鼠标复原为系统原生默认指针",
        "btn_apply": "一键更换 (Apply)",
        "btn_apply_help": "立即将当前方案应用到 macOS 系统光标",
        "btn_restore": "一键恢复 (Restore)",
        "btn_restore_help": "一键恢复 macOS 原生默认光标",
        "btn_export_cape": "导出 .cape 文件",
        "btn_export_cape_help": "导出为 macOS 专用的 .cape 光标主题包",
        "btn_export_assets": "导出素材包",
        "btn_export_assets_help": "导出各光标的 PNG 图片与动图帧",
        "language_menu": "语言 (Language)",

        // Actions & Dialogs
        "open_panel_message": "选择包含 Windows 光标（.cur / .ani）的文件夹或文件",
        "import_success_toast": "成功导入并存入方案库【%@】（共 %d 项光标）！",
        "import_fail_error": "导入失败: %@",
        "path_not_exist": "所选路径不存在",
        "apply_success_toast": "已成功更换系统光标！%d/%d 个系统状态已激活生效。",
        "apply_fail_error": "更换系统光标失败，可能受限于当前系统环境权限。已支持导出 .cape 配合 Mousecape 使用。",
        "restore_success_toast": "已成功恢复 macOS 原生默认光标！",
        "restore_fail_error": "未能完全恢复默认光标，可尝试在【系统设置 > 辅助功能 > 显示 > 指针】中重置。",
        "save_cape_message": "选择导出 .cape 文件的保存位置",
        "export_cape_success_toast": "已成功导出【%@】！双击即可在 macOS 中直接使用。",
        "export_cape_fail_error": "导出失败: %@",
        "export_assets_prompt": "导出到此文件夹",
        "export_assets_message": "选择导出图片素材的目标文件夹",
        "export_assets_success_toast": "已成功导出方案图片素材至【%@】！",
        "export_assets_fail_error": "导出素材失败: %@",
        "cape_err_serialization": "无法将光标方案序列化为 .cape 属性列表",
        "cape_err_empty": "光标方案中没有可导出的光标",

        // Detail View
        "frames_count_badge": "%d 帧动画",
        "background_label": "背景",
        "bg_checkerboard": "棋盘格",
        "bg_light": "纯白",
        "bg_dark": "纯黑",
        "show_hotspot_marker": "显示点击锚点 (Hotspot 准星)",
        "frame_step_label": "帧: %d / %d",
        "playback_speed": "播放速度: %.1fx",
        "spec_source_file": "源文件:",
        "spec_cursor_size": "光标尺寸:",
        "spec_cursor_size_val": "%d × %d 像素",
        "spec_hotspot": "点击锚点:",
        "spec_hotspot_val": "X: %d, Y: %d",
        "spec_frame_duration": "单帧时长:",
        "spec_frame_duration_val": "%.3f 秒 (~ %d FPS)",
        "filmstrip_title": "动画序列帧列表 (%d 帧)",
        "system_mappings_title": "适配的 macOS 系统光标标识符 (System Mappings)",

        // Playground
        "playground_title": "鼠标试用体验画板 (Playground)",
        "playground_clicks": "测试点击次数: %d",
        "playground_hover_hint": "把鼠标移入此区域，即可即时体验【%@】的手感与点击对准度",
        "playground_align_hint": "点击此区域可测试准星对齐效果",

        // Item View
        "badge_animated": "%d帧动画",
        "badge_static": "静态",
        "item_hotspot": "热点: (%d, %d)",
        "item_size": "尺寸: %d×%d",

        // Status Bar Menu
        "status_bar_tooltip": "WinToMacCursor - 鼠标方案快速切换",
        "menu_status_custom": "● 当前光标: %@",
        "menu_status_custom_fallback": "已自定义",
        "menu_status_default": "○ 当前光标: 系统默认",
        "menu_schemes_header": "快速切换光标方案:",
        "menu_empty_schemes": "  (方案库暂无方案，请打开主窗口导入)",
        "menu_animated_prefix": "✨ [动态]",
        "menu_static_prefix": "🖱️ [静态]",
        "menu_scheme_item": "%@ %@ (%d 项)",
        "menu_restore_defaults": "↺ 一键恢复系统默认",
        "menu_open_main_window": "🪟 打开主窗口...",
        "menu_settings": "⚙️ 设置...",
        "menu_quit": "🚪 退出 WinToMacCursor",

        // Settings Window
        "settings_title": "设置",
        "settings_general_tab": "通用",
        "settings_language_section": "语言设置",
        "settings_language_label": "界面语言:",
        "settings_dock_section": "菜单栏与程序坞 (Dock)",
        "settings_hide_dock_icon": "隐藏程序坞 (Dock) 图标",
        "settings_hide_dock_icon_desc": "开启后应用仅在顶部菜单栏常驻，不占用程序坞与任务切换器 (Cmd+Tab)，需打开窗口时点击菜单栏图标即可。",
        "settings_termination_section": "退出行为",
        "settings_restore_on_quit": "完全退出时恢复系统默认光标",
        "settings_restore_on_quit_desc": "完全退出应用时，自动将所有鼠标指针重置还原为 macOS 原生系统默认样式。",
        "settings_about_section": "关于",
        "settings_version_label": "版本 %@ (%@)",
        "settings_about_description": "专为 macOS 打造的原生 Windows .cur 与 .ani 光标转换与管理器。",

        // Roles
        "role_arrow": "正常选择 (Normal)",
        "role_help": "帮助选择 (Help)",
        "role_working": "后台工作 (Working)",
        "role_busy": "忙碌等待 (Busy)",
        "role_precision": "精确定位 / 截屏选择 (Precision)",
        "role_text": "文本选择 (Text/IBeam)",
        "role_handwriting": "手写输入 (Handwriting)",
        "role_unavailable": "禁止/不可用 (Unavailable)",
        "role_vertical": "垂直缩放 (Vertical)",
        "role_horizontal": "水平缩放 (Horizontal)",
        "role_diagonal1": "对角缩放 1 (Diagonal 1)",
        "role_diagonal2": "对角缩放 2 (Diagonal 2)",
        "role_move": "移动 (Move)",
        "role_alternate": "候选选择 (Alternate)",
        "role_link": "链接选择 (Link/Hand)",
        "role_person": "人员/定位 (Person)",
        "role_pin": "图钉/标记 (Pin)",
        "role_custom": "自定义光标 (Custom)"
    ]
}
