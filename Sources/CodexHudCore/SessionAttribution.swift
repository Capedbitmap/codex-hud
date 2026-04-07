import Foundation

public struct AuthObservation: Codable, Equatable, Sendable {
    public var email: String
    public var subject: String?
    public var accountId: String?
    public var observedAt: Date

    public init(email: String, subject: String?, accountId: String?, observedAt: Date) {
        self.email = email
        self.subject = subject
        self.accountId = accountId
        self.observedAt = observedAt
    }
}

public struct SessionAccountBinding: Codable, Equatable, Sendable {
    public var sessionID: String
    public var rolloutPath: String
    public var email: String
    public var subject: String?
    public var accountId: String?
    public var startedAt: Date
    public var lastObservedAt: Date

    public init(
        sessionID: String,
        rolloutPath: String,
        email: String,
        subject: String?,
        accountId: String?,
        startedAt: Date,
        lastObservedAt: Date
    ) {
        self.sessionID = sessionID
        self.rolloutPath = rolloutPath
        self.email = email
        self.subject = subject
        self.accountId = accountId
        self.startedAt = startedAt
        self.lastObservedAt = lastObservedAt
    }
}
