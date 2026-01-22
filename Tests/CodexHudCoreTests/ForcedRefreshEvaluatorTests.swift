import XCTest
@testable import CodexHudCore

final class ForcedRefreshEvaluatorTests: XCTestCase {
    func testBlocksWhenWeeklyDepleted() {
        let evaluator = ForcedRefreshEvaluator()
        let remaining = Percent(rawValue: 4)!
        let decision = evaluator.decision(now: Date(), weeklyRemaining: remaining, record: nil, hasAuth: true)
        XCTAssertFalse(decision.allowed)
        XCTAssertEqual(decision.reason, .weeklyDepleted)
    }

    func testBlocksWhenTooSoon() {
        let evaluator = ForcedRefreshEvaluator()
        let record = ForcedRefreshRecord(lastAttempt: Date(), lastSuccess: nil, lastFailure: nil)
        let decision = evaluator.decision(now: Date(), weeklyRemaining: Percent(rawValue: 50), record: record, hasAuth: true)
        XCTAssertFalse(decision.allowed)
        XCTAssertEqual(decision.reason, .tooSoon)
    }

    func testAllowsWhenNoRecord() {
        let evaluator = ForcedRefreshEvaluator()
        let decision = evaluator.decision(now: Date(), weeklyRemaining: Percent(rawValue: 50), record: nil, hasAuth: true)
        XCTAssertTrue(decision.allowed)
    }

    func testBlocksAfterRecentFailure() {
        let evaluator = ForcedRefreshEvaluator()
        let record = ForcedRefreshRecord(lastAttempt: nil, lastSuccess: nil, lastFailure: Date())
        let decision = evaluator.decision(now: Date(), weeklyRemaining: Percent(rawValue: 50), record: record, hasAuth: true)
        XCTAssertFalse(decision.allowed)
        XCTAssertEqual(decision.reason, .recentFailure)
    }
}
