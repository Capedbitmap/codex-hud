import XCTest
@testable import CodexHudCore

final class DailyHelloEvaluatorTests: XCTestCase {
    func testRunsWhenNoPriorDate() {
        let evaluator = DailyHelloEvaluator()
        XCTAssertTrue(evaluator.shouldRun(now: Date(), lastRun: nil))
    }

    func testSkipsSameDay() {
        let evaluator = DailyHelloEvaluator()
        let now = Date()
        XCTAssertFalse(evaluator.shouldRun(now: now, lastRun: now))
    }

    func testRunsOnNewDay() {
        let evaluator = DailyHelloEvaluator()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        XCTAssertTrue(evaluator.shouldRun(now: Date(), lastRun: yesterday))
    }
}
