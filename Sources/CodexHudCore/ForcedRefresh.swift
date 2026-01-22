import Foundation

public enum ForcedRefreshBlockReason: Equatable, Sendable {
    case noAuth
    case weeklyDepleted
    case tooSoon
    case recentFailure
}

public struct ForcedRefreshDecision: Equatable, Sendable {
    public let allowed: Bool
    public let reason: ForcedRefreshBlockReason?

    public init(allowed: Bool, reason: ForcedRefreshBlockReason?) {
        self.allowed = allowed
        self.reason = reason
    }

    public static let allowedDecision = ForcedRefreshDecision(allowed: true, reason: nil)
}

public struct ForcedRefreshPolicy: Equatable, Sendable {
    public let minimumInterval: TimeInterval
    public let failureCooldown: TimeInterval

    public init(minimumInterval: TimeInterval, failureCooldown: TimeInterval) {
        self.minimumInterval = minimumInterval
        self.failureCooldown = failureCooldown
    }

    public static let `default` = ForcedRefreshPolicy(minimumInterval: 12 * 60 * 60, failureCooldown: 24 * 60 * 60)
}

public struct ForcedRefreshRecord: Codable, Equatable, Sendable {
    public var lastAttempt: Date?
    public var lastSuccess: Date?
    public var lastFailure: Date?

    public init(lastAttempt: Date? = nil, lastSuccess: Date? = nil, lastFailure: Date? = nil) {
        self.lastAttempt = lastAttempt
        self.lastSuccess = lastSuccess
        self.lastFailure = lastFailure
    }
}

public struct ForcedRefreshEvaluator {
    public let policy: ForcedRefreshPolicy
    public let thresholds: UsageThresholds

    public init(policy: ForcedRefreshPolicy = .default, thresholds: UsageThresholds = .default) {
        self.policy = policy
        self.thresholds = thresholds
    }

    public func decision(now: Date, weeklyRemaining: Percent?, record: ForcedRefreshRecord?, hasAuth: Bool) -> ForcedRefreshDecision {
        guard hasAuth else { return ForcedRefreshDecision(allowed: false, reason: .noAuth) }
        if let weeklyRemaining, weeklyRemaining <= thresholds.depleted {
            return ForcedRefreshDecision(allowed: false, reason: .weeklyDepleted)
        }
        if let lastAttempt = record?.lastAttempt, now.timeIntervalSince(lastAttempt) < policy.minimumInterval {
            return ForcedRefreshDecision(allowed: false, reason: .tooSoon)
        }
        if let lastFailure = record?.lastFailure, now.timeIntervalSince(lastFailure) < policy.failureCooldown {
            return ForcedRefreshDecision(allowed: false, reason: .recentFailure)
        }
        return .allowedDecision
    }
}
