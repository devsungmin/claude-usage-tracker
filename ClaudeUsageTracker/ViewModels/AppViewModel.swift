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
    @Published var statusBarText: String = "Claude: --%"
    @Published var accountInfo: String?
    @Published var settings = UserSettings()

    private let apiService = AnthropicAPIService()
    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Try Claude Code credentials first, then session key
        if let credential = KeychainService.getClaudeCodeCredential() {
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
        if let credential = KeychainService.getClaudeCodeCredential() {
            authMethod = .claudeCode
            authState = .loggedIn
            accountInfo = credential.accountEmail
            startAutoRefresh()
            Task { await refreshUsage() }
        } else {
            errorMessage = "Claude Code 인증 정보를 찾을 수 없습니다.\nclaude 명령어로 먼저 로그인해주세요."
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
                    errorMessage = "Claude Code 인증이 만료되었습니다. 다시 로그인해주세요."
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

    /// Returns a user-safe error message without exposing server internals
    private static func sanitizedErrorMessage(_ error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.localizedDescription
        }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return "네트워크 연결을 확인해주세요."
        }
        return "알 수 없는 오류가 발생했습니다."
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
