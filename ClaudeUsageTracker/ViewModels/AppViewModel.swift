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
        let claudeResult = KeychainService.getClaudeCodeCredential()
        let hasClaudeCredential = { if case .found = claudeResult { return true }; return false }()
        let hasExpiredCredential = { if case .expired = claudeResult { return true }; return false }()

        if hasClaudeCredential || hasExpiredCredential {
            authMethod = .claudeCode
            Task {
                let result = await resolveClaudeCodeCredential()
                if let credential = result.credential {
                    authState = .loggedIn
                    accountInfo = credential.accountEmail
                    await refreshUsage()
                }
            }
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
        Task {
            let result = await resolveClaudeCodeCredential()
            if let credential = result.credential {
                authMethod = .claudeCode
                authState = .loggedIn
                accountInfo = credential.accountEmail
                startAutoRefresh()
                await refreshUsage()
            } else {
                errorMessage = result.error
            }
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
                let result = await resolveClaudeCodeCredential()
                guard let credential = result.credential else {
                    errorMessage = result.error
                    authState = .loggedOut
                    isLoading = false
                    return
                }
                accountInfo = credential.accountEmail
                usage = try await apiService.fetchUsageWithOAuth(token: credential.accessToken)

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

    private func resolveClaudeCodeCredential() async -> (credential: ClaudeCodeCredential?, error: String?) {
        switch KeychainService.getClaudeCodeCredential() {
        case .found(let credential):
            return (credential, nil)
        case .expired(let refreshToken):
            if let refreshToken, await tryRefreshOAuthToken(refreshToken),
               case .found(let credential) = KeychainService.getClaudeCodeCredential() {
                return (credential, nil)
            }
            return (nil, String(localized: "error.claude_code_expired"))
        case .notFound:
            return (nil, String(localized: "error.claude_code_not_found"))
        }
    }

    private func tryRefreshOAuthToken(_ refreshToken: String) async -> Bool {
        do {
            let response = try await apiService.refreshOAuthToken(refreshToken: refreshToken)
            let expiresAt = Date().timeIntervalSince1970 * 1000 + Double(response.expires_in) * 1000
            KeychainService.updateClaudeCodeOAuthTokens(
                accessToken: response.access_token,
                refreshToken: response.refresh_token,
                expiresAt: expiresAt
            )
            return true
        } catch {
            return false
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
