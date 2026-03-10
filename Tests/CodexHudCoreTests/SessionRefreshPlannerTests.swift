import XCTest
@testable import CodexHudCore

final class SessionRefreshPlannerTests: XCTestCase {
    func testPrefersLatestMappedThreadOverCurrentAuth() {
        let planner = SessionRefreshPlanner()
        let base = Date(timeIntervalSince1970: 1_762_000_000)

        let state = AppState(
            accounts: [
                AccountRecord(codexNumber: 1, email: "alpha@example.com", displayName: nil, lastSnapshot: nil, lastUpdated: nil),
                AccountRecord(codexNumber: 2, email: "beta@example.com", displayName: nil, lastSnapshot: nil, lastUpdated: nil)
            ],
            activeEmail: "beta@example.com",
            lastRefresh: nil,
            authObservations: [
                AuthObservation(email: "alpha@example.com", subject: "sub-alpha", accountId: "acct-alpha", observedAt: base),
                AuthObservation(email: "beta@example.com", subject: "sub-beta", accountId: "acct-beta", observedAt: base.addingTimeInterval(100))
            ]
        )

        let alphaPath = tempRolloutPath("alpha")
        let betaPath = tempRolloutPath("beta")
        let threads = [
            CodexThreadActivity(
                sessionID: "session-alpha",
                updatedAt: base.addingTimeInterval(300),
                rolloutPath: alphaPath,
                cwd: "/tmp/alpha"
            ),
            CodexThreadActivity(
                sessionID: "session-beta",
                updatedAt: base.addingTimeInterval(200),
                rolloutPath: betaPath,
                cwd: "/tmp/beta"
            )
        ]

        let metadataByPath = [
            alphaPath: SessionMetadata(
                sessionID: "session-alpha",
                startedAt: base.addingTimeInterval(10),
                cwd: "/tmp/alpha"
            ),
            betaPath: SessionMetadata(
                sessionID: "session-beta",
                startedAt: base.addingTimeInterval(110),
                cwd: "/tmp/beta"
            )
        ]

        let fileManager = FileManager.default
        for path in metadataByPath.keys {
            fileManager.createFile(atPath: path, contents: Data(), attributes: nil)
        }
        defer {
            for path in metadataByPath.keys {
                try? fileManager.removeItem(atPath: path)
            }
        }

        let plan = planner.plan(
            state: state,
            configuredEmails: Set(state.accounts.map(\.email)),
            recentThreads: threads,
            metadataByRolloutPath: metadataByPath,
            currentIdentity: AuthAccountIdentity(email: "beta@example.com", subject: "sub-beta", accountId: "acct-beta"),
            observedAt: base.addingTimeInterval(100),
            now: base.addingTimeInterval(400)
        )

        XCTAssertEqual(plan.bindings["session-alpha"]?.email, "alpha@example.com")
        XCTAssertEqual(plan.bindings["session-beta"]?.email, "beta@example.com")
        XCTAssertEqual(plan.activeEmail, "alpha@example.com")
        XCTAssertEqual(plan.candidateRolloutPaths, [alphaPath, betaPath])
    }

    func testFallsBackToCurrentAuthWhenNoMappedThreadExists() {
        let planner = SessionRefreshPlanner()
        let state = AppState(
            accounts: [AccountRecord(codexNumber: 1, email: "beta@example.com", displayName: nil, lastSnapshot: nil, lastUpdated: nil)],
            activeEmail: nil,
            lastRefresh: nil
        )

        let plan = planner.plan(
            state: state,
            configuredEmails: ["beta@example.com"],
            recentThreads: [],
            metadataByRolloutPath: [:],
            currentIdentity: AuthAccountIdentity(email: "beta@example.com", subject: "sub-beta", accountId: "acct-beta"),
            observedAt: Date(timeIntervalSince1970: 1_762_000_000),
            now: Date(timeIntervalSince1970: 1_762_000_100)
        )

        XCTAssertEqual(plan.activeEmail, "beta@example.com")
        XCTAssertTrue(plan.bindings.isEmpty)
        XCTAssertTrue(plan.candidateRolloutPaths.isEmpty)
    }

    private func tempRolloutPath(_ name: String) -> String {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-hud-\(name).jsonl")
            .path
    }
}
