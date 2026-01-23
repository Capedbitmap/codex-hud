import Foundation

public struct DailyHelloRecord: Codable, Equatable, Sendable {
    public var lastRun: Date?
    public var dayAnchor: Date?
    public var runCount: Int

    public init(lastRun: Date? = nil, dayAnchor: Date? = nil, runCount: Int = 0) {
        self.lastRun = lastRun
        self.dayAnchor = dayAnchor
        self.runCount = runCount
    }

    private enum CodingKeys: String, CodingKey {
        case lastRun
        case dayAnchor
        case runCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.lastRun = try container.decodeIfPresent(Date.self, forKey: .lastRun)
        self.dayAnchor = try container.decodeIfPresent(Date.self, forKey: .dayAnchor)
        self.runCount = try container.decodeIfPresent(Int.self, forKey: .runCount) ?? 0
    }
}

public struct DailyHelloPolicy: Equatable, Sendable {
    public let startHour: Int
    public let endHour: Int
    public let maxRunsPerDay: Int
    public let minimumInterval: TimeInterval

    public init(
        startHour: Int = 6,
        endHour: Int = 20,
        maxRunsPerDay: Int = 3,
        minimumInterval: TimeInterval = 4 * 60 * 60
    ) {
        self.startHour = startHour
        self.endHour = endHour
        self.maxRunsPerDay = maxRunsPerDay
        self.minimumInterval = minimumInterval
    }
}

public enum DailyHelloBlockReason: Equatable, Sendable {
    case outsideWindow
    case dailyLimitReached
    case tooSoon
    case fiveHourStarted
}

public enum DailyHelloDecision: Equatable, Sendable {
    case allowed(updatedRecord: DailyHelloRecord)
    case blocked(DailyHelloBlockReason)
}

public struct DailyHelloEvaluator {
    public init() {}

    public func decision(
        now: Date,
        record: DailyHelloRecord?,
        policy: DailyHelloPolicy,
        fiveHourStarted: Bool
    ) -> DailyHelloDecision {
        let calendar = Calendar.current
        guard let windowStart = calendar.date(bySettingHour: policy.startHour, minute: 0, second: 0, of: now),
              let windowEnd = calendar.date(bySettingHour: policy.endHour, minute: 0, second: 0, of: now) else {
            return .blocked(.outsideWindow)
        }
        guard now >= windowStart, now <= windowEnd else {
            return .blocked(.outsideWindow)
        }
        let startOfDay = calendar.startOfDay(for: now)
        let isSameDay = record?.dayAnchor.map { calendar.isDate($0, inSameDayAs: now) } ?? false
        let runCount = isSameDay ? (record?.runCount ?? 0) : 0
        if runCount >= policy.maxRunsPerDay {
            return .blocked(.dailyLimitReached)
        }
        if let lastRun = record?.lastRun, now.timeIntervalSince(lastRun) < policy.minimumInterval {
            return .blocked(.tooSoon)
        }
        if fiveHourStarted {
            return .blocked(.fiveHourStarted)
        }
        let updated = DailyHelloRecord(lastRun: now, dayAnchor: startOfDay, runCount: runCount + 1)
        return .allowed(updatedRecord: updated)
    }
}
