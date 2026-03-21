import Foundation

struct UsageLimit: Codable, Equatable {
    let usedPercent: Double
    let resetTime: Date?

    var formattedPercent: String {
        "\(Int(usedPercent))%"
    }

    var formattedResetTime: String {
        guard let resetTime = resetTime else { return "--" }

        let interval = resetTime.timeIntervalSince(Date())
        if interval <= 0 { return "곧 재설정" }

        if interval < 3600 {
            return "\(Int(interval / 60))분 후 재설정"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)시간 \(minutes)분 후 재설정"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "ko_KR")
            dateFormatter.dateFormat = "(E) a h:mm에 재설정"
            return dateFormatter.string(from: resetTime)
        }
    }

    var effectivePercent: Double {
        if let resetTime = resetTime, resetTime < Date() {
            return 0
        }
        return usedPercent
    }
}

struct UsageData: Codable, Equatable {
    let fiveHour: UsageLimit
    let sevenDay: UsageLimit
    let sevenDayOpus: UsageLimit
    let sevenDaySonnet: UsageLimit
    let lastUpdated: Date

    var formattedLastUpdated: String {
        let interval = Date().timeIntervalSince(lastUpdated)
        if interval < 60 {
            return "방금 전"
        } else if interval < 3600 {
            return "\(Int(interval / 60))분 전"
        } else {
            return "\(Int(interval / 3600))시간 전"
        }
    }

    static let empty = UsageData(
        fiveHour: UsageLimit(usedPercent: 0, resetTime: nil),
        sevenDay: UsageLimit(usedPercent: 0, resetTime: nil),
        sevenDayOpus: UsageLimit(usedPercent: 0, resetTime: nil),
        sevenDaySonnet: UsageLimit(usedPercent: 0, resetTime: nil),
        lastUpdated: Date()
    )
}
