import Foundation

public struct DailyHelloRecord: Codable, Equatable, Sendable {
    public var lastRun: Date?

    public init(lastRun: Date? = nil) {
        self.lastRun = lastRun
    }
}

public struct DailyHelloEvaluator {
    public init() {}

    public func shouldRun(now: Date, lastRun: Date?) -> Bool {
        guard let lastRun else { return true }
        let calendar = Calendar.current
        return !calendar.isDate(lastRun, inSameDayAs: now)
    }
}
