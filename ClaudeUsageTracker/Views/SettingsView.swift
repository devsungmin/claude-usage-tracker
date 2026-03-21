import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: AppViewModel

    private let refreshIntervals: [(String, TimeInterval)] = [
        ("1분", 60),
        ("5분", 300),
        ("15분", 900),
    ]

    var body: some View {
        Form {
            Section("상단바 표시") {
                Picker("표시할 항목", selection: $viewModel.settings.displayMode) {
                    ForEach(StatusBarDisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
            }

            Section("새로고침") {
                Picker("새로고침 간격", selection: $viewModel.settings.refreshInterval) {
                    ForEach(refreshIntervals, id: \.1) { name, interval in
                        Text(name).tag(interval)
                    }
                }
            }

            Section("일반") {
                Toggle("로그인 시 자동 실행", isOn: $viewModel.settings.launchAtLogin)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 400, height: 260)
    }
}
