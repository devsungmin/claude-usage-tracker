import Foundation
import Combine
import ServiceManagement

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case system = "system"
    case en = "en"
    case ko = "ko"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return String(localized: "language.system")
        case .en: return "English"
        case .ko: return "한국어"
        }
    }
}

enum StatusBarDisplayMode: String, Codable, CaseIterable, Identifiable {
    case fiveHour = "five_hour"
    case sevenDay = "seven_day"
    case sevenDaySonnet = "seven_day_sonnet"
    case sevenDayOpus = "seven_day_opus"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fiveHour: return String(localized: "mode.five_hour")
        case .sevenDay: return String(localized: "mode.seven_day")
        case .sevenDaySonnet: return String(localized: "mode.seven_day_sonnet")
        case .sevenDayOpus: return String(localized: "mode.seven_day_opus")
        }
    }

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
    @Published var language: AppLanguage {
        didSet {
            save()
            applyLanguage()
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
        self.language = AppLanguage(rawValue: defaults.string(forKey: "language") ?? "") ?? .system
        applyLanguage()
    }

    private func save() {
        defaults.set(displayMode.rawValue, forKey: "displayMode")
        defaults.set(refreshInterval, forKey: "refreshInterval")
        defaults.set(launchAtLogin, forKey: "launchAtLogin")
        defaults.set(language.rawValue, forKey: "language")
    }

    private func applyLanguage() {
        switch language {
        case .system:
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        case .en, .ko:
            UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
        }
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
