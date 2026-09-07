import AppKit
import SwiftUI
import UniformTypeIdentifiers

public struct ContentView: View {
    @StateObject private var cursorManager = SystemCursorManager.shared
    @ObservedObject private var libraryManager = SchemeLibraryManager.shared
    @AppStorage("WinToMacCursor_RestoreOnQuit") private var restoreOnQuit: Bool = false

    @State private var statusMessage: String? = nil
    @State private var errorMessage: String? = nil
    @State private var isShowingToast: Bool = false

    public init() {}

    public var body: some View {
        NavigationSplitView {
            sidebarView
        } content: {
            cursorListView
        } detail: {
            cursorDetailView
        }
        .frame(minWidth: 960, minHeight: 620)
        .toolbar {
            toolbarItems
        }
        .overlay(alignment: .top) {
            if let msg = statusMessage {
                toastView(message: msg, isError: false)
            } else if let err = errorMessage {
                toastView(message: err, isError: true)
            }
        }
    }

    // MARK: - Sidebar
    private var sidebarView: some View {
        VStack(spacing: 0) {
            List(selection: $libraryManager.selectedSchemeIndex) {
                Section(header: Text("光标方案库 (Themes)")) {
                    ForEach(libraryManager.schemes.indices, id: \.self) { idx in
                        let scheme = libraryManager.schemes[idx]
                        HStack {
                            Image(systemName: scheme.isAnimatedScheme ? "sparkles" : "cursorarrow.motionlines")
                                .foregroundColor(scheme.isAnimatedScheme ? .orange : .blue)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(scheme.name)
                                    .font(.system(size: 13, weight: .medium))
                                Text("\(scheme.items.count) 项光标")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .tag(idx)
                        .contextMenu {
                            Button(role: .destructive) {
                                libraryManager.deleteScheme(at: idx)
                                showToast("已从方案库中移除【\(scheme.name)】")
                            } label: {
                                Label("从方案库中删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            // Import Button
            Button(action: promptImportDirectory) {
                Label("导入文件夹 / .cur / .ani...", systemImage: "folder.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(12)

            // System Status Card
            HStack(spacing: 8) {
                Circle()
                    .fill(cursorManager.isCustomApplied ? Color.green : Color.secondary.opacity(0.5))
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(cursorManager.isCustomApplied ? "当前状态: 自定义光标已生效" : "当前状态: 系统默认光标")
                        .font(.system(size: 11, weight: .medium))
                    if let last = cursorManager.lastAppliedSchemeName {
                        Text("已应用: \(last)")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
    }

    // MARK: - Cursor List
    private var cursorListView: some View {
        Group {
            if let currentScheme = activeScheme {
                VStack(spacing: 0) {
                    // Scheme Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(currentScheme.name)
                                    .font(.headline)
                                if currentScheme.isAnimatedScheme {
                                    Text("动态 ANI 方案")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.15))
                                        .foregroundColor(.orange)
                                        .cornerRadius(4)
                                } else {
                                    Text("静态 CUR 方案")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.15))
                                        .foregroundColor(.blue)
                                        .cornerRadius(4)
                                }
                            }
                            Text("共包含 \(currentScheme.items.count) 种光标，支持适配 macOS 系统核心状态")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(Color(NSColor.controlBackgroundColor))

                    Divider()

                    // List of Cursors
                    List(currentScheme.items, selection: $libraryManager.selectedItemId) { item in
                        CursorItemView(item: item, isSelected: libraryManager.selectedItemId == item.id)
                            .onTapGesture {
                                libraryManager.selectedItemId = item.id
                            }
                    }
                    .listStyle(.inset)
                }
            } else {
                Text("暂无选中的光标方案")
                    .foregroundColor(.secondary)
            }
        }
        .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 360)
    }

    // MARK: - Cursor Detail
    private var cursorDetailView: some View {
        Group {
            if let currentScheme = activeScheme,
               let item = currentScheme.items.first(where: { $0.id == libraryManager.selectedItemId }) ?? currentScheme.items.first {
                CursorDetailView(item: item)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "cursorarrow.click")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("请在左侧列表中选择一个光标进行预览与试用")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Toolbar Items
    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            // Restore on Quit option
            Toggle("退出时恢复默认", isOn: $restoreOnQuit)
                .toggleStyle(.checkbox)
                .font(.caption)
                .help("完全退出 App 时自动将鼠标复原为系统原生默认指针")

            // Apply Button
            Button(action: applyCurrentScheme) {
                Label("一键更换 (Apply)", systemImage: "bolt.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
            .help("立即将当前方案应用到 macOS 系统光标")

            // Restore Button
            Button(action: restoreSystemDefaults) {
                Label("一键恢复 (Restore)", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
            .help("一键恢复 macOS 原生默认光标")

            // Export .cape Button
            Button(action: promptExportCape) {
                Label("导出 .cape 文件", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
            .help("导出为 macOS 专用的 .cape 光标主题包")

            // Export Assets Button
            Button(action: promptExportAssets) {
                Label("导出素材包", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(.bordered)
            .help("导出各光标的 PNG 图片与动图帧")
        }
    }

    // MARK: - Actions
    private var activeScheme: CursorScheme? {
        libraryManager.activeScheme
    }

    private func promptImportDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType.folder, UTType(filenameExtension: "cur")!, UTType(filenameExtension: "ani")!]
        panel.message = "选择包含 Windows 光标（.cur / .ani）的文件夹或文件"

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let imported = try libraryManager.importScheme(from: url)
                showToast("成功导入并存入方案库【\(imported.name)】（共 \(imported.items.count) 项光标）！")
            } catch {
                showError("导入失败: \(error.localizedDescription)")
            }
        }
    }

    private func applyCurrentScheme() {
        guard let scheme = activeScheme else { return }
        let (success, total) = cursorManager.applyScheme(scheme)
        if success > 0 {
            showToast("已成功更换系统光标！\(success)/\(total) 个系统状态已激活生效。")
        } else {
            showError("更换系统光标失败，可能受限于当前系统环境权限。已支持导出 .cape 配合 Mousecape 使用。")
        }
    }

    private func restoreSystemDefaults() {
        let ok = cursorManager.restoreDefaults()
        if ok {
            showToast("已成功恢复 macOS 原生默认光标！")
        } else {
            showError("未能完全恢复默认光标，可尝试在【系统设置 > 辅助功能 > 显示 > 指针】中重置。")
        }
    }

    private func promptExportCape() {
        guard let scheme = activeScheme else { return }
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType(filenameExtension: "cape") ?? .data]
        savePanel.nameFieldStringValue = "\(scheme.name).cape"
        savePanel.message = "选择导出 .cape 文件的保存位置"

        if savePanel.runModal() == .OK, let destination = savePanel.url {
            do {
                try CapeGenerator.exportCape(from: scheme, to: destination)
                showToast("已成功导出【\(destination.lastPathComponent)】！双击即可在 macOS 中直接使用。")
            } catch {
                showError("导出失败: \(error.localizedDescription)")
            }
        }
    }

    private func promptExportAssets() {
        guard let scheme = activeScheme else { return }
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.canCreateDirectories = true
        openPanel.prompt = "导出到此文件夹"
        openPanel.message = "选择导出图片素材的目标文件夹"

        if openPanel.runModal() == .OK, let targetDir = openPanel.url {
            do {
                let schemeDir = targetDir.appendingPathComponent(scheme.name)
                try FileManager.default.createDirectory(at: schemeDir, withIntermediateDirectories: true)

                for item in scheme.items {
                    if item.isAnimated {
                        // Export vertical sprite sheet
                        if let sprite = CapeGenerator.createVerticalSpriteSheet(frames: item.frames.map(\.image), singleSize: item.size) {
                            let fileURL = schemeDir.appendingPathComponent("\(item.name)_spritesheet.png")
                            try sprite.write(to: fileURL)
                        }
                        // Export individual frames
                        let framesDir = schemeDir.appendingPathComponent("\(item.name)_frames")
                        try FileManager.default.createDirectory(at: framesDir, withIntermediateDirectories: true)
                        for (idx, frame) in item.frames.enumerated() {
                            if let tiff = frame.image.tiffRepresentation,
                               let rep = NSBitmapImageRep(data: tiff),
                               let png = rep.representation(using: .png, properties: [:]) {
                                let frameURL = framesDir.appendingPathComponent("frame_\(String(format: "%02d", idx + 1)).png")
                                try png.write(to: frameURL)
                            }
                        }
                    } else if let img = item.frames.first?.image,
                              let tiff = img.tiffRepresentation,
                              let rep = NSBitmapImageRep(data: tiff),
                              let png = rep.representation(using: .png, properties: [:]) {
                        let fileURL = schemeDir.appendingPathComponent("\(item.name).png")
                        try png.write(to: fileURL)
                    }
                }
                showToast("已成功导出方案图片素材至【\(schemeDir.lastPathComponent)】！")
            } catch {
                showError("导出素材失败: \(error.localizedDescription)")
            }
        }
    }

    private func showToast(_ message: String) {
        self.statusMessage = message
        self.errorMessage = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            if self.statusMessage == message {
                self.statusMessage = nil
            }
        }
    }

    private func showError(_ message: String) {
        self.errorMessage = message
        self.statusMessage = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
            if self.errorMessage == message {
                self.errorMessage = nil
            }
        }
    }

    private func toastView(message: String, isError: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundColor(isError ? .red : .green)
            Text(message)
                .font(.system(size: 13, weight: .medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 4)
        )
        .padding(.top, 16)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut, value: message)
    }
}
