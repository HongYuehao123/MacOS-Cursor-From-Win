import AppKit
import SwiftUI
import UniformTypeIdentifiers

public struct ContentView: View {
    @StateObject private var cursorManager = SystemCursorManager.shared
    @ObservedObject private var libraryManager = SchemeLibraryManager.shared
    @ObservedObject private var langManager = LanguageManager.shared
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
        .navigationTitle(L10n.tr("app_title"))
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
        .onAppear {
            langManager.updateAllWindowsTitle()
        }
        .onChange(of: langManager.selectedLanguageRaw) { _, _ in
            langManager.updateAllWindowsTitle()
        }
    }

    // MARK: - Sidebar
    private var sidebarView: some View {
        VStack(spacing: 0) {
            List(selection: $libraryManager.selectedSchemeIndex) {
                Section(header: Text(L10n.tr("sidebar_section_title"))) {
                    ForEach(libraryManager.schemes.indices, id: \.self) { idx in
                        let scheme = libraryManager.schemes[idx]
                        HStack {
                            Image(systemName: scheme.isAnimatedScheme ? "sparkles" : "cursorarrow.motionlines")
                                .foregroundColor(scheme.isAnimatedScheme ? .orange : .blue)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(scheme.name)
                                    .font(.system(size: 13, weight: .medium))
                                Text(L10n.tr("scheme_items_count", scheme.items.count))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .tag(idx)
                        .contextMenu {
                            Button(role: .destructive) {
                                libraryManager.deleteScheme(at: idx)
                                showToast(L10n.tr("delete_scheme_toast", scheme.name))
                            } label: {
                                Label(L10n.tr("delete_scheme"), systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            // Import Button
            Button(action: promptImportDirectory) {
                Label(L10n.tr("import_button"), systemImage: "folder.badge.plus")
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
                    Text(cursorManager.isCustomApplied ? L10n.tr("status_custom_active") : L10n.tr("status_system_default"))
                        .font(.system(size: 11, weight: .medium))
                    if let last = cursorManager.lastAppliedSchemeName {
                        Text(L10n.tr("status_applied_scheme", last))
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    } else {
                        Text(L10n.tr("status_menu_bar_hint"))
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
                                    Text(L10n.tr("animated_scheme_badge"))
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.15))
                                        .foregroundColor(.orange)
                                        .cornerRadius(4)
                                } else {
                                    Text(L10n.tr("static_scheme_badge"))
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.15))
                                        .foregroundColor(.blue)
                                        .cornerRadius(4)
                                }
                            }
                            Text(L10n.tr("scheme_summary", currentScheme.items.count))
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
                Text(L10n.tr("no_scheme_selected"))
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
                    Text(L10n.tr("select_cursor_prompt"))
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
            // Language Picker Menu
            Menu {
                ForEach(AppLanguage.allCases) { lang in
                    Button {
                        langManager.selectedLanguage = lang
                    } label: {
                        HStack {
                            Text(lang.displayName)
                            if langManager.selectedLanguage == lang {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label(L10n.tr("language_menu"), systemImage: "globe")
            }
            .help(L10n.tr("language_menu"))

            // Restore on Quit option
            Toggle(L10n.tr("restore_on_quit"), isOn: $restoreOnQuit)
                .toggleStyle(.checkbox)
                .font(.caption)
                .help(L10n.tr("restore_on_quit_help"))

            // Apply Button
            Button(action: applyCurrentScheme) {
                Label(L10n.tr("btn_apply"), systemImage: "bolt.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
            .help(L10n.tr("btn_apply_help"))

            // Restore Button
            Button(action: restoreSystemDefaults) {
                Label(L10n.tr("btn_restore"), systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
            .help(L10n.tr("btn_restore_help"))

            // Export .cape Button
            Button(action: promptExportCape) {
                Label(L10n.tr("btn_export_cape"), systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
            .help(L10n.tr("btn_export_cape_help"))

            // Export Assets Button
            Button(action: promptExportAssets) {
                Label(L10n.tr("btn_export_assets"), systemImage: "photo.on.rectangle")
            }
            .buttonStyle(.bordered)
            .help(L10n.tr("btn_export_assets_help"))
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
        panel.message = L10n.tr("open_panel_message")

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let imported = try libraryManager.importScheme(from: url)
                showToast(L10n.tr("import_success_toast", imported.name, imported.items.count))
            } catch {
                showError(L10n.tr("import_fail_error", error.localizedDescription))
            }
        }
    }

    private func applyCurrentScheme() {
        guard let scheme = activeScheme else { return }
        let (success, total) = cursorManager.applyScheme(scheme)
        if success > 0 {
            showToast(L10n.tr("apply_success_toast", success, total))
        } else {
            showError(L10n.tr("apply_fail_error"))
        }
    }

    private func restoreSystemDefaults() {
        let ok = cursorManager.restoreDefaults()
        if ok {
            showToast(L10n.tr("restore_success_toast"))
        } else {
            showError(L10n.tr("restore_fail_error"))
        }
    }

    private func promptExportCape() {
        guard let scheme = activeScheme else { return }
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType(filenameExtension: "cape") ?? .data]
        savePanel.nameFieldStringValue = "\(scheme.name).cape"
        savePanel.message = L10n.tr("save_cape_message")

        if savePanel.runModal() == .OK, let destination = savePanel.url {
            do {
                try CapeGenerator.exportCape(from: scheme, to: destination)
                showToast(L10n.tr("export_cape_success_toast", destination.lastPathComponent))
            } catch {
                showError(L10n.tr("export_cape_fail_error", error.localizedDescription))
            }
        }
    }

    private func promptExportAssets() {
        guard let scheme = activeScheme else { return }
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.canCreateDirectories = true
        openPanel.prompt = L10n.tr("export_assets_prompt")
        openPanel.message = L10n.tr("export_assets_message")

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
                showToast(L10n.tr("export_assets_success_toast", schemeDir.lastPathComponent))
            } catch {
                showError(L10n.tr("export_assets_fail_error", error.localizedDescription))
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
