import Foundation

public struct Percent: Codable, Equatable, Comparable, Sendable {
    public let value: Double

    public init?(rawValue: Double) {
        guard rawValue.isFinite else { return nil }
        guard rawValue >= 0 && rawValue <= 100 else { return nil }
        self.value = rawValue
    }

    public static func < (lhs: Percent, rhs: Percent) -> Bool {
        lhs.value < rhs.value
    }
}
