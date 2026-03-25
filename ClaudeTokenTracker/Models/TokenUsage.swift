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
        if interval <= 0 { return String(localized: "reset.soon") }

        if interval < 3600 {
            let minutes = Int(interval / 60)
            return String(format: String(localized: "reset.minutes"), minutes)
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
            return String(format: String(localized: "reset.hours_minutes"), hours, minutes)
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .short
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
            return String(localized: "updated.just_now")
        } else if interval < 3600 {
            return String(format: String(localized: "updated.minutes_ago"), Int(interval / 60))
        } else {
            return String(format: String(localized: "updated.hours_ago"), Int(interval / 3600))
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
