import XCTest
@testable import CodexHudCore

final class UsageStateTests: XCTestCase {
    func testAssumedResetMarksStale() {
        let past = Date().addingTimeInterval(-3600)
        let window = UsageWindow(kind: .weekly, usedPercent: 80, windowMinutes: 10080, resetsAt: past, isStale: false, assumedReset: false)
        let snapshot = RateLimitsSnapshot(capturedAt: Date(), fiveHour: window, weekly: window, source: .sessionLog)
        let manager = UsageStateManager()
        let now = Date()
        let updated = manager.applyAssumedResetsIfNeeded(snapshot: snapshot, now: now)
        XCTAssertEqual(updated.weekly.usedPercent, 0)
        XCTAssertTrue(updated.weekly.isStale)
        XCTAssertTrue(updated.weekly.assumedReset)
        XCTAssertTrue(updated.weekly.resetsAt >= now)
    }
}
