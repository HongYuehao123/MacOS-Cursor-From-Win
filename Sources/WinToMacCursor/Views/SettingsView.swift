import SwiftUI

public struct SettingsView: View {
    @ObservedObject private var langManager = LanguageManager.shared
    @ObservedObject private var appState = AppStateManager.shared
    @State private var selectedTab: Int

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

            aboutTab
                .tabItem {
                    Label(L10n.tr("settings_about_section"), systemImage: "info.circle")
                }
                .tag(1)
        }
        .frame(width: 490, height: 440)
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

            // 2. Dock & Menu Bar Section
            Section {
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

    // MARK: - About Tab
    private var aboutTab: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "cursorarrow.motionlines")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
                .foregroundColor(.accentColor)

            VStack(spacing: 6) {
                Text("WinToMacCursor")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(String(format: L10n.tr("settings_version_label"), "1.0.0", "1"))
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
}
