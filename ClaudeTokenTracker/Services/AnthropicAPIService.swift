import Foundation

extension Bundle {
    nonisolated var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
}

actor AnthropicAPIService {

    static let userAgent = "ClaudeTokenTracker/\(Bundle.main.appVersion)"

    struct AccountInfo: Codable {
        let uuid: String
        let name: String
    }

    private let session: URLSession = { 
        let config = URLSessionConfiguration.default
        config.tlsMinimumSupportedProtocolVersion = .TLSv12
        config.tlsMaximumSupportedProtocolVersion = .TLSv13
        return URLSession(configuration: config)
    }()

    // MARK: - OAuth Token Refresh

    struct OAuthTokenResponse: Codable {
        let access_token: String
        let refresh_token: String
        let expires_in: Int
    }

    func refreshOAuthToken(refreshToken: String) async throws -> OAuthTokenResponse {
        let sanitized = try Self.sanitizeHeaderValue(refreshToken)
        let url = URL(string: "https://console.anthropic.com/v1/oauth/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "grant_type": "refresh_token",
            "refresh_token": sanitized,
            "client_id": "9d1c250a-e61b-44d9-88ed-5944d1962f5e",
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)

        return try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
    }

    // MARK: - Fetch via Session Cookie (Primary)

    func fetchUsageWithSession(sessionKey: String) async throws -> UsageData {
        let sanitized = try Self.sanitizeHeaderValue(sessionKey)
        let orgId = try await fetchOrgId(headers: sessionHeaders(sanitized))
        return try await fetchUsage(orgId: orgId, headers: sessionHeaders(sanitized))
    }

    // MARK: - Fetch via OAuth Token (Claude Code)

    func fetchUsageWithOAuth(token: String) async throws -> UsageData {
        let sanitized = try Self.sanitizeHeaderValue(token)
        // Try the dedicated usage endpoint first
        do {
            let orgId = try await fetchOrgId(headers: oauthHeaders(sanitized))
            return try await fetchUsage(orgId: orgId, headers: oauthHeaders(sanitized))
        } catch {
            // Fallback: read rate-limit headers from Messages API
            return try await fetchUsageFromHeaders(token: sanitized)
        }
    }

    // MARK: - Organizations

    private func fetchOrgId(headers: [String: String]) async throws -> String {
        let url = URL(string: "https://claude.ai/api/organizations")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)

        let orgs = try JSONDecoder().decode([AccountInfo].self, from: data)
        guard let org = orgs.first else {
            throw APIError.noOrganization
        }
        return org.uuid
    }

    // MARK: - Usage Endpoint

    private func fetchUsage(orgId: String, headers: [String: String]) async throws -> UsageData {
        guard let encodedOrgId = orgId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://claude.ai/api/organizations/\(encodedOrgId)/usage") else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)

        return try parseUsageResponse(data: data)
    }

    private func parseUsageResponse(data: Data) throws -> UsageData {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.parseError
        }

        let fiveHour = parseUtilization(json["five_hour"])
        let sevenDay = parseUtilization(json["seven_day"])
        let sevenDayOpus = parseUtilization(json["seven_day_opus"])
        let sevenDaySonnet = parseUtilization(json["seven_day_sonnet"])

        return UsageData(
            fiveHour: fiveHour,
            sevenDay: sevenDay,
            sevenDayOpus: sevenDayOpus,
            sevenDaySonnet: sevenDaySonnet,
            lastUpdated: Date()
        )
    }

    private func parseUtilization(_ value: Any?) -> UsageLimit {
        guard let dict = value as? [String: Any] else {
            return UsageLimit(usedPercent: 0, resetTime: nil)
        }

        // utilization can be Int, Double, or String
        let utilization: Double
        if let intVal = dict["utilization"] as? Int {
            utilization = Double(intVal)
        } else if let doubleVal = dict["utilization"] as? Double {
            utilization = doubleVal
        } else if let strVal = dict["utilization"] as? String, let parsed = Double(strVal) {
            utilization = parsed
        } else {
            utilization = 0
        }

        var resetTime: Date?
        if let resetStr = dict["resets_at"] as? String {
            resetTime = parseISO8601(resetStr)
        }

        return UsageLimit(usedPercent: utilization, resetTime: resetTime)
    }

    // MARK: - Fallback: Messages API Headers

    private func fetchUsageFromHeaders(token: String) async throws -> UsageData {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 1,
            "messages": [["role": "user", "content": "hi"]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        let headers = httpResponse.allHeaderFields

        // Read unified utilization headers (0.0 - 1.0)
        let fiveHourUtil = headerDouble(headers, key: "anthropic-ratelimit-unified-5h-utilization") * 100
        let sevenDayUtil = headerDouble(headers, key: "anthropic-ratelimit-unified-7d-utilization") * 100

        return UsageData(
            fiveHour: UsageLimit(usedPercent: fiveHourUtil, resetTime: nil),
            sevenDay: UsageLimit(usedPercent: sevenDayUtil, resetTime: nil),
            sevenDayOpus: UsageLimit(usedPercent: 0, resetTime: nil),
            sevenDaySonnet: UsageLimit(usedPercent: 0, resetTime: nil),
            lastUpdated: Date()
        )
    }

    // MARK: - Headers

    private func sessionHeaders(_ sessionKey: String) -> [String: String] {
        [
            "Cookie": "sessionKey=\(sessionKey)",
            "Accept": "application/json",
        ]
    }

    private func oauthHeaders(_ token: String) -> [String: String] {
        [
            "Authorization": "Bearer \(token)",
            "anthropic-version": "2023-06-01",
            "anthropic-beta": "oauth-2025-04-20",
            "User-Agent": Self.userAgent,
            "Accept": "application/json",
        ]
    }

    // MARK: - Helpers

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    private func headerDouble(_ headers: [AnyHashable: Any], key: String) -> Double {
        if let str = headers[key] as? String, let val = Double(str) { return val }
        return 0
    }

    private func parseISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string) ?? ISO8601DateFormatter().date(from: string)
    }

    /// Reject header values containing CR/LF to prevent HTTP header injection
    static func sanitizeHeaderValue(_ value: String) throws -> String {
        if value.contains("\r") || value.contains("\n") || value.contains("\0") {
            throw APIError.invalidInput
        }
        return value
    }
}

enum APIError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int)
    case noOrganization
    case parseError
    case invalidInput

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return String(localized: "error.server_response")
        case .httpError(let code):
            return String(format: String(localized: "error.http_code"), code)
        case .noOrganization:
            return String(localized: "error.no_organization")
        case .parseError:
            return String(localized: "error.parse")
        case .invalidInput:
            return String(localized: "error.invalid_input")
        }
    }
}
