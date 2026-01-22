import XCTest
@testable import CodexHudCore

final class StorageTests: XCTestCase {
    func testRoundTripState() throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = AppStateStore(fileURL: tempURL)
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshot = RateLimitsSnapshot(
            capturedAt: fixedDate,
            fiveHour: UsageWindow(kind: .fiveHour, usedPercent: 10, windowMinutes: 300, resetsAt: fixedDate, isStale: false, assumedReset: false),
            weekly: UsageWindow(kind: .weekly, usedPercent: 90, windowMinutes: 10080, resetsAt: fixedDate, isStale: false, assumedReset: false),
            source: .sessionLog
        )
        let state = AppState(
            accounts: [AccountRecord(codexNumber: 2, email: "user@example.com", displayName: nil, lastSnapshot: snapshot, lastUpdated: fixedDate)],
            activeEmail: "user@example.com",
            lastRefresh: fixedDate
        )

        try store.save(state)
        let loaded = try store.load()
        XCTAssertEqual(loaded, state)
    }
}
