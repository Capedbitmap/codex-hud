import Foundation

public struct WeeklyResetReminderEvent: Equatable, Sendable {
    public let accountEmail: String
    public let codexNumber: Int
    public let resetsAt: Date

    public init(accountEmail: String, codexNumber: Int, resetsAt: Date) {
        self.accountEmail = accountEmail
        self.codexNumber = codexNumber
        self.resetsAt = resetsAt
    }
}
