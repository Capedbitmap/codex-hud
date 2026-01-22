import XCTest
@testable import CodexHudCore

final class NotificationEvaluatorTests: XCTestCase {
    func testWeeklyWarningCrossingEmitsEvent() {
        let evaluator = NotificationEvaluator()
        let account = makeAccount(weeklyUsed: 92, fiveHourUsed: 10)
        let previous = ThresholdSnapshot(weekly: .normal, fiveHour: .normal)
        let evaluation = evaluator.evaluate(account: account, previous: previous)
        XCTAssertEqual(evaluation?.events.count, 1)
        XCTAssertEqual(evaluation?.events.first?.window, .weekly)
        XCTAssertEqual(evaluation?.events.first?.level, .warning)
    }

    func testWeeklyCriticalCrossingEmitsEvent() {
        let evaluator = NotificationEvaluator()
        let account = makeAccount(weeklyUsed: 96, fiveHourUsed: 10)
        let previous = ThresholdSnapshot(weekly: .warning, fiveHour: .normal)
        let evaluation = evaluator.evaluate(account: account, previous: previous)
        XCTAssertEqual(evaluation?.events.first?.level, .critical)
    }

    func testFiveHourSuppressedWhenWeeklyDepleted() {
        let evaluator = NotificationEvaluator()
        let account = makeAccount(weeklyUsed: 95, fiveHourUsed: 98)
        let evaluation = evaluator.evaluate(account: account, previous: nil)
        let hasFiveHourEvent = evaluation?.events.contains(where: { $0.window == .fiveHour }) ?? false
        XCTAssertFalse(hasFiveHourEvent)
        XCTAssertNil(evaluation?.snapshot.fiveHour)
    }

    private func makeAccount(weeklyUsed: Double, fiveHourUsed: Double) -> AccountRecord {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let fiveHour = UsageWindow(kind: .fiveHour, usedPercent: fiveHourUsed, windowMinutes: 300, resetsAt: now, isStale: false, assumedReset: false)
        let weekly = UsageWindow(kind: .weekly, usedPercent: weeklyUsed, windowMinutes: 10080, resetsAt: now, isStale: false, assumedReset: false)
        let snapshot = RateLimitsSnapshot(capturedAt: now, fiveHour: fiveHour, weekly: weekly, source: .sessionLog)
        return AccountRecord(codexNumber: 2, email: "user@example.com", displayName: nil, lastSnapshot: snapshot, lastUpdated: now)
    }
}
