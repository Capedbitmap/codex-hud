import Foundation

public struct UsageThresholds: Equatable, Sendable {
    public let depleted: Percent
    public let warning: Percent

    public init(depleted: Percent, warning: Percent) {
        self.depleted = depleted
        self.warning = warning
    }

    public static var `default`: UsageThresholds {
        let depleted = Percent(rawValue: 5)!
        let warning = Percent(rawValue: 10)!
        return UsageThresholds(depleted: depleted, warning: warning)
    }
}
