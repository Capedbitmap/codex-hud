import Foundation

public struct ThresholdSet: Equatable, Sendable {
    public let critical: Percent
    public let warning: Percent
    public let caution: Percent

    public init(critical: Percent, warning: Percent, caution: Percent) {
        self.critical = critical
        self.warning = warning
        self.caution = caution
    }

    public static let `default` = ThresholdSet(
        critical: Percent(rawValue: 5)!,
        warning: Percent(rawValue: 15)!,
        caution: Percent(rawValue: 30)!
    )
}
