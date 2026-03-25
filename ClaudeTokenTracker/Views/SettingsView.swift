import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var showRestartHint = false

    private let refreshIntervals: [(String, TimeInterval)] = [
        (String(localized: "interval.1min"), 60),
        (String(localized: "interval.5min"), 300),
        (String(localized: "interval.15min"), 900),
    ]

    var body: some View {
        Form {
            Section("settings.status_bar_display") {
                Picker("settings.display_item", selection: $viewModel.settings.displayMode) {
                    ForEach(StatusBarDisplayMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
            }

            Section("settings.refresh") {
                Picker("settings.refresh_interval", selection: $viewModel.settings.refreshInterval) {
                    ForEach(refreshIntervals, id: \.1) { name, interval in
                        Text(name).tag(interval)
                    }
                }
            }

            Section("settings.general") {
                Toggle("settings.launch_at_login", isOn: $viewModel.settings.launchAtLogin)

                Picker("settings.language", selection: $viewModel.settings.language) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .onChange(of: viewModel.settings.language) {
                    showRestartHint = true
                }

                if showRestartHint {
                    Text("settings.language_restart")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 400, height: 300)
    }
}
