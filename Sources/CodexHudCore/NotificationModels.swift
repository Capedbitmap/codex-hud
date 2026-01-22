import Foundation

public enum ThresholdLevel: Int, Codable, Comparable, Sendable {
    case normal = 0
    case warning = 1
    case critical = 2

    public static func < (lhs: ThresholdLevel, rhs: ThresholdLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct ThresholdSnapshot: Codable, Equatable, Sendable {
    public let weekly: ThresholdLevel
    public let fiveHour: ThresholdLevel?

    public init(weekly: ThresholdLevel, fiveHour: ThresholdLevel?) {
        self.weekly = weekly
        self.fiveHour = fiveHour
    }
}

public struct NotificationEvent: Equatable, Sendable {
    public let accountEmail: String
    public let codexNumber: Int
    public let window: UsageWindowKind
    public let level: ThresholdLevel
    public let remainingPercent: Percent

    public init(accountEmail: String, codexNumber: Int, window: UsageWindowKind, level: ThresholdLevel, remainingPercent: Percent) {
        self.accountEmail = accountEmail
        self.codexNumber = codexNumber
        self.window = window
        self.level = level
        self.remainingPercent = remainingPercent
    }
}

public struct NotificationEvaluation: Equatable, Sendable {
    public let snapshot: ThresholdSnapshot
    public let events: [NotificationEvent]

    public init(snapshot: ThresholdSnapshot, events: [NotificationEvent]) {
        self.snapshot = snapshot
        self.events = events
    }
}
