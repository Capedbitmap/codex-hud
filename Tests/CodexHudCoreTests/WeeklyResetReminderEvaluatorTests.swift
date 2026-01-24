import XCTest
@testable import CodexHudCore

final class WeeklyResetReminderEvaluatorTests: XCTestCase {
    func testAllowsWhenWeeklyAssumedResetAndUnusedWithinWindow() {
        let evaluator = WeeklyResetReminderEvaluator()
        let policy = WeeklyResetReminderPolicy(startHour: 9, endHour: 22, interval: 5 * 60 * 60)
        let now = Self.date(hour: 10)
        let weekly = UsageWindow(kind: .weekly, usedPercent: 0, windowMinutes: 10080, resetsAt: now, isStale: true, assumedReset: true)
        let decision = evaluator.decision(now: now, weekly: weekly, record: nil, policy: policy)
        guard case .allowed(let record) = decision else {
            return XCTFail("Expected allowed decision")
        }
        XCTAssertEqual(record.lastNotified, now)
    }

    func testBlocksOutsideWindow() {
        let evaluator = WeeklyResetReminderEvaluator()
        let policy = WeeklyResetReminderPolicy(startHour: 9, endHour: 22, interval: 5 * 60 * 60)
        let now = Self.date(hour: 7)
        let weekly = UsageWindow(kind: .weekly, usedPercent: 0, windowMinutes: 10080, resetsAt: now, isStale: true, assumedReset: true)
        XCTAssertEqual(evaluator.decision(now: now, weekly: weekly, record: nil, policy: policy), .blocked)
    }

    func testBlocksWhenUsed() {
        let evaluator = WeeklyResetReminderEvaluator()
        let policy = WeeklyResetReminderPolicy(startHour: 9, endHour: 22, interval: 5 * 60 * 60)
        let now = Self.date(hour: 12)
        let weekly = UsageWindow(kind: .weekly, usedPercent: 5, windowMinutes: 10080, resetsAt: now, isStale: true, assumedReset: true)
        XCTAssertEqual(evaluator.decision(now: now, weekly: weekly, record: nil, policy: policy), .blocked)
    }

    func testBlocksWhenTooSoon() {
        let evaluator = WeeklyResetReminderEvaluator()
        let policy = WeeklyResetReminderPolicy(startHour: 9, endHour: 22, interval: 5 * 60 * 60)
        let now = Self.date(hour: 14)
        let weekly = UsageWindow(kind: .weekly, usedPercent: 0, windowMinutes: 10080, resetsAt: now, isStale: true, assumedReset: true)
        let record = WeeklyReminderRecord(lastNotified: now.addingTimeInterval(-2 * 60 * 60))
        XCTAssertEqual(evaluator.decision(now: now, weekly: weekly, record: record, policy: policy), .blocked)
    }

    private static func date(hour: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 24
        components.hour = hour
        components.minute = 0
        components.second = 0
        return Calendar.current.date(from: components) ?? Date()
    }
}
