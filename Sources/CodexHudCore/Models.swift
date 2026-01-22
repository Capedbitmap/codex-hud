import Foundation

public enum UsageWindowKind: String, Codable {
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

    public init(accounts: [AccountRecord], activeEmail: String?, lastRefresh: Date?) {
        self.accounts = accounts
        self.activeEmail = activeEmail
        self.lastRefresh = lastRefresh
    }
}
