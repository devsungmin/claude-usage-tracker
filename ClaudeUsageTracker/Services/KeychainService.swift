import Foundation
import Security

struct ClaudeCodeCredential {
    let accessToken: String
    let accountEmail: String?
}

enum CredentialResult {
    case found(ClaudeCodeCredential)
    case expired
    case notFound
}

enum KeychainService {
    private static let service = "com.claudeusagetracker"
    private static let sessionKeyAccount = "claude-session-key"

    // MARK: - Session Key

    static func saveSessionKey(_ key: String) throws {
        try save(service: service, account: sessionKeyAccount, data: key)
    }

    static func getSessionKey() -> String? {
        get(service: service, account: sessionKeyAccount)
    }

    static func deleteSessionKey() {
        delete(service: service, account: sessionKeyAccount)
    }

    // MARK: - Claude Code OAuth Token

    static func getClaudeCodeOAuthToken() -> String? {
        if case .found(let credential) = getClaudeCodeCredential() {
            return credential.accessToken
        }
        return nil
    }

    static func getClaudeCodeCredential() -> CredentialResult {
        // 1. Try keychain first
        let keychainResult = readClaudeCodeKeychain()
        if case .found = keychainResult { return keychainResult }
        if case .expired = keychainResult { return .expired }

        // 2. Fallback: try reading from ~/.claude/.credentials.json
        let fileResult = readCredentialsFile()
        if case .found(let token) = fileResult {
            return .found(ClaudeCodeCredential(accessToken: token, accountEmail: nil))
        }
        if case .expired = fileResult { return .expired }

        return .notFound
    }

    private enum FileCredentialResult {
        case found(String)
        case expired
        case notFound
    }

    private static func readCredentialsFile() -> FileCredentialResult {
        let paths = [
            NSHomeDirectory() + "/.claude/.credentials.json",
            NSHomeDirectory() + "/.claude/credentials.json",
        ]

        for path in paths {
            guard let data = FileManager.default.contents(atPath: path),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            if let oauth = json["claudeAiOauth"] as? [String: Any],
               let accessToken = oauth["accessToken"] as? String {
                // Check expiry
                if let expiresAt = oauth["expiresAt"] as? Double {
                    let expiryDate = Date(timeIntervalSince1970: expiresAt / 1000)
                    if expiryDate < Date() { return .expired }
                }
                return .found(accessToken)
            }
        }
        return .notFound
    }

    private static func readClaudeCodeKeychain() -> CredentialResult {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let item = result as? [String: Any],
              let data = item[kSecValueData as String] as? Data,
              let jsonString = String(data: data, encoding: .utf8),
              let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return .notFound
        }

        let account = item[kSecAttrAccount as String] as? String

        if let oauth = json["claudeAiOauth"] as? [String: Any],
           let token = oauth["accessToken"] as? String {
            // Check expiry
            if let expiresAtMs = oauth["expiresAt"] as? Double {
                let expiryDate = Date(timeIntervalSince1970: expiresAtMs / 1000)
                if expiryDate < Date() { return .expired }
            }
            return .found(ClaudeCodeCredential(accessToken: token, accountEmail: account))
        }

        return .notFound
    }

    // MARK: - Session Key Validation

    static func isValidSessionKeyFormat(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.hasPrefix("sk-ant-sid01-"),
              !trimmed.contains("\r"),
              !trimmed.contains("\n"),
              !trimmed.contains("\0") else {
            return false
        }
        return true
    }

    // MARK: - Internal

    private static func save(service: String, account: String, data: String) throws {
        guard let dataBytes = data.data(using: .utf8) else { return }
        delete(service: service, account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: dataBytes,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            throw KeychainError.saveFailed(status)
        }
    }

    private static func get(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private static func delete(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return String(format: String(localized: "error.keychain_save"), Int32(status))
        }
    }
}
