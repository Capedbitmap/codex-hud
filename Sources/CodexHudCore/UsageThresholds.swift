import Foundation

public struct UsageThresholds: Equatable, Sendable {
    public let depleted: Percent
    public let warning: Percent
    public let caution: Percent

    public init(depleted: Percent, warning: Percent, caution: Percent) {
        self.depleted = depleted
        self.warning = warning
        self.caution = caution
    }

    public static var `default`: UsageThresholds {
        UsageThresholds(
            depleted: ThresholdSet.default.critical,
            warning: ThresholdSet.default.warning,
            caution: ThresholdSet.default.caution
        )
    }
}
