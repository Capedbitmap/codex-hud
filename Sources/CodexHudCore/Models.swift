import Foundation

public enum UsageWindowKind: String, Codable, Sendable {
    case fiveHour
    case weekly
}

public struct UsageWindow: Codable, Equatable {
    public let kind: UsageWindowKind
    public var usedPercent: Double
    public var windowMinutes: Int
    public var resetsAt: Date
    public var isStale: Bool
    public var assumedReset: Bool

    public init(kind: UsageWindowKind, usedPercent: Double, windowMinutes: Int, resetsAt: Date, isStale: Bool, assumedReset: Bool) {
        self.kind = kind
        self.usedPercent = usedPercent
        self.windowMinutes = windowMinutes
        self.resetsAt = resetsAt
        self.isStale = isStale
        self.assumedReset = assumedReset
    }
}

public struct RateLimitsSnapshot: Codable, Equatable {
    public var capturedAt: Date
    public var fiveHour: UsageWindow
    public var weekly: UsageWindow
    public var source: SnapshotSource

    public init(capturedAt: Date, fiveHour: UsageWindow, weekly: UsageWindow, source: SnapshotSource) {
        self.capturedAt = capturedAt
        self.fiveHour = fiveHour
        self.weekly = weekly
        self.source = source
    }
}

public enum SnapshotSource: String, Codable {
    case sessionLog
    case forcedRefresh
}

public struct AccountRecord: Codable, Equatable {
    public var codexNumber: Int
    public var email: String
    public var displayName: String?
    public var lastSnapshot: RateLimitsSnapshot?
    public var lastUpdated: Date?

    public init(codexNumber: Int, email: String, displayName: String?, lastSnapshot: RateLimitsSnapshot?, lastUpdated: Date?) {
        self.codexNumber = codexNumber
        self.email = email
        self.displayName = displayName
        self.lastSnapshot = lastSnapshot
        self.lastUpdated = lastUpdated
    }
}

public struct AppState: Codable, Equatable {
    public var accounts: [AccountRecord]
    public var activeEmail: String?
    public var lastRefresh: Date?
    public var notificationLedger: [String: ThresholdSnapshot]
    public var forcedRefreshRecords: [String: ForcedRefreshRecord]
    public var dailyHelloRecords: [String: DailyHelloRecord]
    public var weeklyReminderRecords: [String: WeeklyReminderRecord]

    public init(
        accounts: [AccountRecord],
        activeEmail: String?,
        lastRefresh: Date?,
        notificationLedger: [String: ThresholdSnapshot] = [:],
        forcedRefreshRecords: [String: ForcedRefreshRecord] = [:],
        dailyHelloRecords: [String: DailyHelloRecord] = [:],
        weeklyReminderRecords: [String: WeeklyReminderRecord] = [:]
    ) {
        self.accounts = accounts
        self.activeEmail = activeEmail
        self.lastRefresh = lastRefresh
        self.notificationLedger = notificationLedger
        self.forcedRefreshRecords = forcedRefreshRecords
        self.dailyHelloRecords = dailyHelloRecords
        self.weeklyReminderRecords = weeklyReminderRecords
    }

    private enum CodingKeys: String, CodingKey {
        case accounts
        case activeEmail
        case lastRefresh
        case notificationLedger
        case forcedRefreshRecords
        case dailyHelloRecords
        case weeklyReminderRecords
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.accounts = try container.decode([AccountRecord].self, forKey: .accounts)
        self.activeEmail = try container.decodeIfPresent(String.self, forKey: .activeEmail)
        self.lastRefresh = try container.decodeIfPresent(Date.self, forKey: .lastRefresh)
        self.notificationLedger = try container.decodeIfPresent([String: ThresholdSnapshot].self, forKey: .notificationLedger) ?? [:]
        self.forcedRefreshRecords = try container.decodeIfPresent([String: ForcedRefreshRecord].self, forKey: .forcedRefreshRecords) ?? [:]
        self.dailyHelloRecords = try container.decodeIfPresent([String: DailyHelloRecord].self, forKey: .dailyHelloRecords) ?? [:]
        self.weeklyReminderRecords = try container.decodeIfPresent([String: WeeklyReminderRecord].self, forKey: .weeklyReminderRecords) ?? [:]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accounts, forKey: .accounts)
        try container.encodeIfPresent(activeEmail, forKey: .activeEmail)
        try container.encodeIfPresent(lastRefresh, forKey: .lastRefresh)
        try container.encode(notificationLedger, forKey: .notificationLedger)
        try container.encode(forcedRefreshRecords, forKey: .forcedRefreshRecords)
        try container.encode(dailyHelloRecords, forKey: .dailyHelloRecords)
        try container.encode(weeklyReminderRecords, forKey: .weeklyReminderRecords)
    }
}
