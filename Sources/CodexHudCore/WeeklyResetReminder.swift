import Foundation

public struct WeeklyReminderRecord: Codable, Equatable, Sendable {
    public var lastNotified: Date?

    public init(lastNotified: Date? = nil) {
        self.lastNotified = lastNotified
    }
}

public struct WeeklyResetReminderPolicy: Equatable, Sendable {
    public let startHour: Int
    public let endHour: Int
    public let interval: TimeInterval

    public init(startHour: Int = 9, endHour: Int = 22, interval: TimeInterval = 5 * 60 * 60) {
        self.startHour = startHour
        self.endHour = endHour
        self.interval = interval
    }
}

public enum WeeklyReminderDecision: Equatable, Sendable {
    case allowed(nextRecord: WeeklyReminderRecord)
    case blocked
}

public struct WeeklyResetReminderEvaluator {
    public init() {}

    public func decision(
        now: Date,
        weekly: UsageWindow,
        record: WeeklyReminderRecord?,
        policy: WeeklyResetReminderPolicy
    ) -> WeeklyReminderDecision {
        guard weekly.usedPercent == 0 else { return .blocked }
        if !weekly.assumedReset, now < weekly.resetsAt {
            return .blocked
        }
        let calendar = Calendar.current
        guard let windowStart = calendar.date(bySettingHour: policy.startHour, minute: 0, second: 0, of: now),
              let windowEnd = calendar.date(bySettingHour: policy.endHour, minute: 0, second: 0, of: now) else {
            return .blocked
        }
        guard now >= windowStart, now <= windowEnd else { return .blocked }
        if let lastNotified = record?.lastNotified, now.timeIntervalSince(lastNotified) < policy.interval {
            return .blocked
        }
        return .allowed(nextRecord: WeeklyReminderRecord(lastNotified: now))
    }
}
