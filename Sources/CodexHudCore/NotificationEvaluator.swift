import Foundation

public struct NotificationEvaluator {
    public let thresholds: UsageThresholds

    public init(thresholds: UsageThresholds = .default) {
        self.thresholds = thresholds
    }

    public func evaluate(account: AccountRecord, previous: ThresholdSnapshot?) -> NotificationEvaluation? {
        guard let snapshot = account.lastSnapshot else { return nil }
        guard let weeklyUsed = Percent(rawValue: snapshot.weekly.usedPercent) else { return nil }
        guard let weeklyRemaining = Percent(rawValue: 100 - weeklyUsed.value) else { return nil }

        let weeklyLevel = level(for: weeklyRemaining)
        let allowFiveHour = weeklyRemaining > thresholds.depleted

        let fiveHourLevel: ThresholdLevel?
        var fiveHourRemaining: Percent?
        if allowFiveHour, let fiveHourUsed = Percent(rawValue: snapshot.fiveHour.usedPercent) {
            fiveHourRemaining = Percent(rawValue: 100 - fiveHourUsed.value)
            if let remaining = fiveHourRemaining {
                fiveHourLevel = level(for: remaining)
            } else {
                fiveHourLevel = nil
            }
        } else {
            fiveHourLevel = nil
        }

        let currentSnapshot = ThresholdSnapshot(weekly: weeklyLevel, fiveHour: fiveHourLevel)
        var events: [NotificationEvent] = []

        if shouldNotify(previous: previous?.weekly, current: weeklyLevel) {
            events.append(NotificationEvent(
                accountEmail: account.email,
                codexNumber: account.codexNumber,
                window: .weekly,
                level: weeklyLevel,
                remainingPercent: weeklyRemaining
            ))
        }

        if let fiveHourLevel, let remaining = fiveHourRemaining {
            if shouldNotify(previous: previous?.fiveHour, current: fiveHourLevel) {
                events.append(NotificationEvent(
                    accountEmail: account.email,
                    codexNumber: account.codexNumber,
                    window: .fiveHour,
                    level: fiveHourLevel,
                    remainingPercent: remaining
                ))
            }
        }

        return NotificationEvaluation(snapshot: currentSnapshot, events: events)
    }

    private func level(for remaining: Percent) -> ThresholdLevel {
        if remaining <= thresholds.depleted {
            return .critical
        }
        if remaining <= thresholds.warning {
            return .warning
        }
        return .normal
    }

    private func shouldNotify(previous: ThresholdLevel?, current: ThresholdLevel) -> Bool {
        guard current != .normal else { return false }
        guard let previous else { return true }
        return current > previous
    }
}
