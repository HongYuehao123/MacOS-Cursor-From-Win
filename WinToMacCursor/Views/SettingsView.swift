import SwiftUI
import ServiceManagement

public struct SettingsView: View {
    @ObservedObject private var langManager = LanguageManager.shared
    @ObservedObject private var appState = AppStateManager.shared
    @StateObject private var cursorManager = SystemCursorManager.shared
    @StateObject private var libraryManager = SchemeLibraryManager.shared
    
    @State private var selectedTab: Int = 0
    @State private var launchAtLogin: Bool = (SMAppService.mainApp.status == .enabled)

    public init(selectedTab: Int = 0) {
        _selectedTab = State(initialValue: selectedTab)
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            generalTab
                .tabItem {
                    Label(L10n.tr("settings_general_tab"), systemImage: "gearshape")
                }
                .tag(0)

            cursorTab
                .tabItem {
                    Label(L10n.tr("sidebar_section_title"), systemImage: "cursorarrow.rays")
                }
                .tag(1)

            aboutTab
                .tabItem {
                    Label(L10n.tr("settings_about_section"), systemImage: "info.circle")
                }
                .tag(2)
        }
        .frame(width: 520, height: 420)
    }

    // MARK: - General Settings Tab
    private var generalTab: some View {
        Form {
            // 1. Language Section
            Section {
                Picker(L10n.tr("settings_language_label"), selection: $langManager.selectedLanguage) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text(L10n.tr("settings_language_section"))
            }

            // 2. System Launch & Dock Section
            Section {
                Toggle("开机自动启动", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        updateLaunchAtLogin(enabled: newValue)
                    }

                Toggle(L10n.tr("settings_hide_dock_icon"), isOn: $appState.hideDockIcon)
                Text(L10n.tr("settings_hide_dock_icon_desc"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text(L10n.tr("settings_dock_section"))
            }

            // 3. Termination / Quit Behavior Section
            Section {
                Toggle(L10n.tr("settings_restore_on_quit"), isOn: $appState.restoreOnQuit)
                Text(L10n.tr("settings_restore_on_quit_desc"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text(L10n.tr("settings_termination_section"))
            }
        }
        .formStyle(.grouped)
        .padding(12)
    }

    // MARK: - Cursor Preferences Tab
    private var cursorTab: some View {
        Form {
            Section {
                Picker("激活的光标方案：", selection: $libraryManager.selectedSchemeIndex) {
                    ForEach(libraryManager.schemes.indices, id: \.self) { idx in
                        let scheme = libraryManager.schemes[idx]
                        Text(scheme.name).tag(idx)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: libraryManager.selectedSchemeIndex) { newIdx in
                    if newIdx >= 0 && newIdx < libraryManager.schemes.count {
                        let scheme = libraryManager.schemes[newIdx]
                        _ = cursorManager.applyScheme(scheme)
                    }
                }

                HStack {
                    Text("当前系统光标状态：")
                    Spacer()
                    if cursorManager.isCustomApplied {
                        Text(cursorManager.lastAppliedSchemeName ?? "已自定义")
                            .foregroundColor(.accentColor)
                            .bold()
                    } else {
                        Text("系统原生默认")
                            .foregroundColor(.secondary)
                    }
                }

                Button("一键还原为系统默认光标") {
                    cursorManager.restoreDefaults()
                }
            } header: {
                Text("方案管理")
            }
        }
        .formStyle(.grouped)
        .padding(12)
    }

    // MARK: - About Tab
    private var aboutTab: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "cursorarrow.motionlines")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 56, height: 56)
                .foregroundColor(.accentColor)

            VStack(spacing: 6) {
                Text("WinToMacCursor")
                    .font(.title2)
                    .fontWeight(.bold)

                let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0.0"
                let buildVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
                Text(String(format: L10n.tr("settings_version_label"), appVersion, buildVersion))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
            }

            Text(L10n.tr("settings_about_description"))
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Divider()
                .padding(.horizontal, 40)
                .padding(.vertical, 4)

            VStack(spacing: 4) {
                Text("CoreGraphics & SkyLight Cursor Injection")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Supports .cur, .ani, and .cape formats")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.8))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }

    private func updateLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status == .enabled { return }
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("[SettingsView] Failed to toggle launch at login: \(error.localizedDescription)")
            self.launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
    }
}
