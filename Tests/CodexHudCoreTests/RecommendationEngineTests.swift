import XCTest
@testable import CodexHudCore

final class RecommendationEngineTests: XCTestCase {
    func testStickinessPrefersActiveAccount() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let active = makeAccount(email: "a@example.com", codex: 2, weeklyUsed: 20, resetOffset: 60 * 60 * 24)
        let other = makeAccount(email: "b@example.com", codex: 3, weeklyUsed: 20, resetOffset: 60 * 60)
        let engine = RecommendationEngine()
        let decision = engine.recommend(accounts: [active, other], activeEmail: active.email)
        XCTAssertEqual(decision.recommended?.email, active.email)
        XCTAssertEqual(decision.reason, .stickiness(activeEmail: active.email))
        XCTAssertEqual(active.lastSnapshot?.capturedAt, now)
    }

    func testEarliestResetWinsWhenActiveDepleted() {
        let active = makeAccount(email: "a@example.com", codex: 2, weeklyUsed: 98, resetOffset: 60 * 60 * 24)
        let other = makeAccount(email: "b@example.com", codex: 3, weeklyUsed: 20, resetOffset: 60 * 60)
        let engine = RecommendationEngine()
        let decision = engine.recommend(accounts: [active, other], activeEmail: active.email)
        XCTAssertEqual(decision.recommended?.email, other.email)
        XCTAssertEqual(decision.reason, .earliestWeeklyReset)
    }

    func testTieBreakersPreferHigherRemaining() {
        let resetOffset = TimeInterval(60 * 60 * 6)
        let lowRemaining = makeAccount(email: "a@example.com", codex: 2, weeklyUsed: 90, resetOffset: resetOffset)
        let highRemaining = makeAccount(email: "b@example.com", codex: 3, weeklyUsed: 20, resetOffset: resetOffset)
        let engine = RecommendationEngine()
        let decision = engine.recommend(accounts: [lowRemaining, highRemaining], activeEmail: nil)
        XCTAssertEqual(decision.recommended?.email, highRemaining.email)
    }

    func testAllDepletedPicksEarliestReset() {
        let first = makeAccount(email: "a@example.com", codex: 2, weeklyUsed: 98, resetOffset: 60 * 60 * 24)
        let second = makeAccount(email: "b@example.com", codex: 3, weeklyUsed: 97, resetOffset: 60 * 60 * 12)
        let engine = RecommendationEngine()
        let decision = engine.recommend(accounts: [first, second], activeEmail: nil)
        XCTAssertEqual(decision.recommended?.email, second.email)
        XCTAssertEqual(decision.reason, .allDepleted)
    }

    func testNoDataReturnsNoRecommendation() {
        let account = AccountRecord(codexNumber: 2, email: "a@example.com", displayName: nil, lastSnapshot: nil, lastUpdated: nil)
        let engine = RecommendationEngine()
        let decision = engine.recommend(accounts: [account], activeEmail: nil)
        XCTAssertNil(decision.recommended)
        XCTAssertEqual(decision.reason, .noData)
    }

    func testPrioritizeOrdersByStickinessThenReset() {
        let active = makeAccount(email: "a@example.com", codex: 2, weeklyUsed: 20, resetOffset: 60 * 60 * 6)
        let soonest = makeAccount(email: "b@example.com", codex: 3, weeklyUsed: 20, resetOffset: 60 * 60)
        let later = makeAccount(email: "c@example.com", codex: 4, weeklyUsed: 20, resetOffset: 60 * 60 * 12)
        let unknown = AccountRecord(codexNumber: 5, email: "d@example.com", displayName: nil, lastSnapshot: nil, lastUpdated: nil)
        let engine = RecommendationEngine()
        let ordered = engine.prioritize(accounts: [later, active, unknown, soonest], activeEmail: active.email)
        XCTAssertEqual(ordered.map(\.email), [active.email, soonest.email, later.email, unknown.email])
    }

    private func makeAccount(email: String, codex: Int, weeklyUsed: Double, resetOffset: TimeInterval) -> AccountRecord {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let resetDate = now.addingTimeInterval(resetOffset)
        let fiveHour = UsageWindow(kind: .fiveHour, usedPercent: 10, windowMinutes: 300, resetsAt: now.addingTimeInterval(60 * 60), isStale: false, assumedReset: false)
        let weekly = UsageWindow(kind: .weekly, usedPercent: weeklyUsed, windowMinutes: 10080, resetsAt: resetDate, isStale: false, assumedReset: false)
        let snapshot = RateLimitsSnapshot(capturedAt: now, fiveHour: fiveHour, weekly: weekly, source: .sessionLog)
        return AccountRecord(codexNumber: codex, email: email, displayName: nil, lastSnapshot: snapshot, lastUpdated: now)
    }
}
