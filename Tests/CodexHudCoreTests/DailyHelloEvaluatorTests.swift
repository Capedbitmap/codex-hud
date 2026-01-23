import XCTest
@testable import CodexHudCore

final class DailyHelloEvaluatorTests: XCTestCase {
    func testAllowsWithinWindowWhenNoRecordAndNotStarted() {
        let evaluator = DailyHelloEvaluator()
        let policy = DailyHelloPolicy()
        let now = Self.date(hour: 9)
        let decision = evaluator.decision(now: now, record: nil, policy: policy, fiveHourStarted: false)
        guard case .allowed(let updated) = decision else {
            return XCTFail("Expected allowed decision")
        }
        XCTAssertEqual(updated.runCount, 1)
        XCTAssertEqual(updated.dayAnchor, Calendar.current.startOfDay(for: now))
    }

    func testBlocksOutsideWindow() {
        let evaluator = DailyHelloEvaluator()
        let policy = DailyHelloPolicy()
        let beforeWindow = Self.date(hour: 5)
        let afterWindow = Self.date(hour: 21)
        XCTAssertEqual(
            evaluator.decision(now: beforeWindow, record: nil, policy: policy, fiveHourStarted: false),
            .blocked(.outsideWindow)
        )
        XCTAssertEqual(
            evaluator.decision(now: afterWindow, record: nil, policy: policy, fiveHourStarted: false),
            .blocked(.outsideWindow)
        )
    }

    func testBlocksWhenDailyLimitReached() {
        let evaluator = DailyHelloEvaluator()
        let policy = DailyHelloPolicy(maxRunsPerDay: 3)
        let now = Self.date(hour: 10)
        let record = DailyHelloRecord(
            lastRun: now,
            dayAnchor: Calendar.current.startOfDay(for: now),
            runCount: 3
        )
        XCTAssertEqual(
            evaluator.decision(now: now, record: record, policy: policy, fiveHourStarted: false),
            .blocked(.dailyLimitReached)
        )
    }

    func testBlocksWhenTooSoon() {
        let evaluator = DailyHelloEvaluator()
        let policy = DailyHelloPolicy(minimumInterval: 4 * 60 * 60)
        let now = Self.date(hour: 11)
        let lastRun = Calendar.current.date(byAdding: .hour, value: -2, to: now)
        let record = DailyHelloRecord(
            lastRun: lastRun,
            dayAnchor: Calendar.current.startOfDay(for: now),
            runCount: 1
        )
        XCTAssertEqual(
            evaluator.decision(now: now, record: record, policy: policy, fiveHourStarted: false),
            .blocked(.tooSoon)
        )
    }

    func testBlocksWhenFiveHourStarted() {
        let evaluator = DailyHelloEvaluator()
        let policy = DailyHelloPolicy()
        let now = Self.date(hour: 12)
        XCTAssertEqual(
            evaluator.decision(now: now, record: nil, policy: policy, fiveHourStarted: true),
            .blocked(.fiveHourStarted)
        )
    }

    private static func date(hour: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 23
        components.hour = hour
        components.minute = 0
        components.second = 0
        return Calendar.current.date(from: components) ?? Date()
    }
}
