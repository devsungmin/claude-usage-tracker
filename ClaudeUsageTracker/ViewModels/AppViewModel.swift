import Foundation
import Combine

enum AuthMethod {
    case claudeCode
    case sessionKey
}

enum AuthState: Equatable {
    case loggedOut
    case loggedIn
}

@MainActor
class AppViewModel: ObservableObject {
    @Published var authState: AuthState = .loggedOut
    @Published var authMethod: AuthMethod = .claudeCode
    @Published var usage: UsageData = .empty
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var statusBarText: String = "5h: --%"
    @Published var accountInfo: String?
    @Published var settings = UserSettings()

    private let apiService = AnthropicAPIService()
    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init() {
        if case .found(let credential) = KeychainService.getClaudeCodeCredential() {
            authState = .loggedIn
            authMethod = .claudeCode
            accountInfo = credential.accountEmail
            Task { await refreshUsage() }
        } else if KeychainService.getSessionKey() != nil {
            authState = .loggedIn
            authMethod = .sessionKey
            Task { await refreshUsage() }
        }
        observeSettings()
        startAutoRefresh()
    }

    private func observeSettings() {
        settings.objectWillChange.sink { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateStatusBarText()
                self?.restartTimer()
            }
        }.store(in: &cancellables)
    }

    func connectClaudeCode() {
        switch KeychainService.getClaudeCodeCredential() {
        case .found(let credential):
            authMethod = .claudeCode
            authState = .loggedIn
            accountInfo = credential.accountEmail
            startAutoRefresh()
            Task { await refreshUsage() }
        case .expired:
            errorMessage = String(localized: "error.claude_code_expired")
        case .notFound:
            errorMessage = String(localized: "error.claude_code_not_found")
        }
    }

    func loginWithSessionKey(_ sessionKey: String) {
        do {
            try KeychainService.saveSessionKey(sessionKey)
            authMethod = .sessionKey
            authState = .loggedIn
            startAutoRefresh()
            Task { await refreshUsage() }
        } catch {
            errorMessage = Self.sanitizedErrorMessage(error)
        }
    }

    func logout() {
        KeychainService.deleteSessionKey()
        authState = .loggedOut
        authMethod = .claudeCode
        accountInfo = nil
        errorMessage = nil
        usage = .empty
        stopAutoRefresh()
        updateStatusBarText()
        URLSession.shared.reset {}
    }

    func refreshUsage() async {
        isLoading = true
        errorMessage = nil

        do {
            switch authMethod {
            case .claudeCode:
                guard let token = KeychainService.getClaudeCodeOAuthToken() else {
                    errorMessage = String(localized: "error.claude_code_expired")
                    authState = .loggedOut
                    isLoading = false
                    return
                }
                usage = try await apiService.fetchUsageWithOAuth(token: token)

            case .sessionKey:
                guard let sessionKey = KeychainService.getSessionKey() else {
                    authState = .loggedOut
                    isLoading = false
                    return
                }
                usage = try await apiService.fetchUsageWithSession(sessionKey: sessionKey)
            }
            updateStatusBarText()
        } catch {
            errorMessage = Self.sanitizedErrorMessage(error)
        }

        isLoading = false
    }

    func startAutoRefresh() {
        restartTimer()
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func restartTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: settings.refreshInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshUsage()
            }
        }
    }

    private static func sanitizedErrorMessage(_ error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.localizedDescription
        }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return String(localized: "error.network")
        }
        return String(localized: "error.unknown")
    }

    func updateStatusBarText() {
        guard authState == .loggedIn else {
            statusBarText = "\(settings.displayMode.shortLabel): --%"
            return
        }

        let limit: UsageLimit
        switch settings.displayMode {
        case .fiveHour:
            limit = usage.fiveHour
        case .sevenDay:
            limit = usage.sevenDay
        case .sevenDaySonnet:
            limit = usage.sevenDaySonnet
        case .sevenDayOpus:
            limit = usage.sevenDayOpus
        }

        statusBarText = "\(settings.displayMode.shortLabel): \(limit.formattedPercent)"
    }
}
