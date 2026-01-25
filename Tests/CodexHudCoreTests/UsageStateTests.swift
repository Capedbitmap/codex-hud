import XCTest
@testable import CodexHudCore

final class UsageStateTests: XCTestCase {
    func testAssumedResetMarksStale() {
        let now = Date()
        let past = now.addingTimeInterval(-3600)
        let window = UsageWindow(kind: .weekly, usedPercent: 80, windowMinutes: 10080, resetsAt: past, isStale: false, assumedReset: false)
        let snapshot = RateLimitsSnapshot(capturedAt: Date(), fiveHour: window, weekly: window, source: .sessionLog)
        let manager = UsageStateManager()
        let updated = manager.applyAssumedResetsIfNeeded(snapshot: snapshot, now: now)
        XCTAssertEqual(updated.weekly.usedPercent, 0)
        XCTAssertTrue(updated.weekly.isStale)
        XCTAssertTrue(updated.weekly.assumedReset)
        XCTAssertTrue(updated.weekly.resetsAt >= now)
    }

    func testAssumedResetRollsForwardMultipleWindows() {
        let now = Date()
        let windowMinutes = 300
        let past = now.addingTimeInterval(-TimeInterval(windowMinutes * 60 * 3))
        let window = UsageWindow(kind: .fiveHour, usedPercent: 50, windowMinutes: windowMinutes, resetsAt: past, isStale: false, assumedReset: false)
        let snapshot = RateLimitsSnapshot(capturedAt: now, fiveHour: window, weekly: window, source: .sessionLog)
        let manager = UsageStateManager()
        let updated = manager.applyAssumedResetsIfNeeded(snapshot: snapshot, now: now)
        XCTAssertTrue(updated.fiveHour.resetsAt > now)
        XCTAssertEqual(updated.fiveHour.usedPercent, 0)
        XCTAssertTrue(updated.fiveHour.assumedReset)
    }
}
