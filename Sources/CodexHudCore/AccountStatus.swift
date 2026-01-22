import Foundation

public enum AccountStatus: Equatable {
    case available(WeeklyState)
    case depleted(WeeklyState)
    case unknown
}

public struct WeeklyState: Equatable {
    public let remainingPercent: Percent
    public let usedPercent: Percent
    public let resetsAt: Date
}

public struct AccountEvaluator {
    public let thresholds: UsageThresholds

    public init(thresholds: UsageThresholds = .default) {
        self.thresholds = thresholds
    }

    public func status(for account: AccountRecord) -> AccountStatus {
        guard let snapshot = account.lastSnapshot else { return .unknown }
        guard let usedPercent = Percent(rawValue: snapshot.weekly.usedPercent) else { return .unknown }
        let remainingValue = 100 - usedPercent.value
        guard let remaining = Percent(rawValue: remainingValue) else { return .unknown }
        let state = WeeklyState(remainingPercent: remaining, usedPercent: usedPercent, resetsAt: snapshot.weekly.resetsAt)
        if remaining <= thresholds.depleted {
            return .depleted(state)
        }
        return .available(state)
    }
}
