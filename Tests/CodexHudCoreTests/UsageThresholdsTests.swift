import XCTest
@testable import CodexHudCore

final class UsageThresholdsTests: XCTestCase {
    func testDefaultThresholdsMatchSpec() {
        XCTAssertEqual(UsageThresholds.default.depleted.value, 5)
        XCTAssertEqual(UsageThresholds.default.warning.value, 15)
        XCTAssertEqual(UsageThresholds.default.caution.value, 30)
    }
}
