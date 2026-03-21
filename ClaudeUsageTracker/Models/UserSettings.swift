import Foundation
import Combine
import ServiceManagement

enum StatusBarDisplayMode: String, Codable, CaseIterable, Identifiable {
    case fiveHour = "현재 세션 (5시간)"
    case sevenDay = "주간 한도 (모든 모델)"
    case sevenDaySonnet = "주간 한도 (Sonnet)"
    case sevenDayOpus = "주간 한도 (Opus)"

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .fiveHour: return "5h"
        case .sevenDay: return "7d"
        case .sevenDaySonnet: return "Sonnet"
        case .sevenDayOpus: return "Opus"
        }
    }
}

class UserSettings: ObservableObject {
    @Published var displayMode: StatusBarDisplayMode {
        didSet { save() }
    }
    @Published var refreshInterval: TimeInterval {
        didSet { save() }
    }
    @Published var launchAtLogin: Bool {
        didSet {
            save()
            updateLaunchAtLogin()
        }
    }

    private let defaults = UserDefaults.standard

    static let allowedIntervals: [TimeInterval] = [60, 300, 900]

    init() {
        self.displayMode = StatusBarDisplayMode(
            rawValue: defaults.string(forKey: "displayMode") ?? ""
        ) ?? .fiveHour
        let stored = defaults.double(forKey: "refreshInterval")
        self.refreshInterval = Self.allowedIntervals.contains(stored) ? stored : 60
        self.launchAtLogin = defaults.bool(forKey: "launchAtLogin")
    }

    private func save() {
        defaults.set(displayMode.rawValue, forKey: "displayMode")
        defaults.set(refreshInterval, forKey: "refreshInterval")
        defaults.set(launchAtLogin, forKey: "launchAtLogin")
    }

    private func updateLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // Silently fail — user can toggle again
            }
        }
    }
}
