import XCTest
import SQLite3
@testable import CodexHudApp
@testable import CodexHudCore

@MainActor
final class AppViewModelRefreshTests: XCTestCase {
    func testRefreshTracksLatestMappedThreadAcrossAuthSwitches() async throws {
        let sandbox = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: sandbox) }

        let sessionsURL = sandbox.appendingPathComponent("sessions", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionsURL, withIntermediateDirectories: true)

        let authURL = sandbox.appendingPathComponent("auth.json")
        let databaseURL = sandbox.appendingPathComponent("state_5.sqlite")
        let storeURL = sandbox.appendingPathComponent("state.json")
        let store = AppStateStore(fileURL: storeURL)

        let base = Date().addingTimeInterval(-600)
        let alphaSessionID = "session-alpha"
        let betaSessionID = "session-beta"
        let alphaRolloutURL = sessionsURL.appendingPathComponent("alpha.jsonl")
        let betaRolloutURL = sessionsURL.appendingPathComponent("beta.jsonl")

        try writeAuthFile(
            to: authURL,
            email: "beta@example.com",
            subject: "sub-beta",
            accountId: "acct-beta"
        )
        try writeRollout(
            to: alphaRolloutURL,
            sessionID: alphaSessionID,
            startedAt: base.addingTimeInterval(10),
            events: [(base.addingTimeInterval(120), 61.0, 12.0)]
        )
        try writeRollout(
            to: betaRolloutURL,
            sessionID: betaSessionID,
            startedAt: base.addingTimeInterval(110),
            events: [(base.addingTimeInterval(130), 15.0, 5.0)]
        )
        try createThreadsDatabase(
            at: databaseURL,
            rows: [
                (alphaSessionID, base.addingTimeInterval(200).timeIntervalSince1970, alphaRolloutURL.path, "/tmp/alpha", 0),
                (betaSessionID, base.addingTimeInterval(150).timeIntervalSince1970, betaRolloutURL.path, "/tmp/beta", 0)
            ]
        )
        XCTAssertEqual(try ThreadActivityStore(databaseURL: databaseURL).recentThreads(limit: 10).map(\.sessionID), [alphaSessionID, betaSessionID])
        XCTAssertEqual(try SessionLogParser().sessionMetadata(inFile: alphaRolloutURL)?.sessionID, alphaSessionID)
        XCTAssertEqual(try SessionLogParser().latestTokenCountEvent(inFile: alphaRolloutURL, since: nil)?.primary?.usedPercent, 61.0)
        let seededState = AppState(
            accounts: [
                AccountRecord(codexNumber: 1, email: "alpha@example.com", displayName: nil, lastSnapshot: nil, lastUpdated: nil),
                AccountRecord(codexNumber: 2, email: "beta@example.com", displayName: nil, lastSnapshot: nil, lastUpdated: nil)
            ],
            activeEmail: nil,
            lastRefresh: nil,
            authObservations: [
                AuthObservation(email: "alpha@example.com", subject: "sub-alpha", accountId: "acct-alpha", observedAt: base),
                AuthObservation(email: "beta@example.com", subject: "sub-beta", accountId: "acct-beta", observedAt: base.addingTimeInterval(100))
            ]
        )
        let preflightPlan = SessionRefreshPlanner().plan(
            state: seededState,
            configuredEmails: Set(seededState.accounts.map(\.email)),
            recentThreads: try ThreadActivityStore(databaseURL: databaseURL).recentThreads(limit: 10),
            metadataByRolloutPath: [
                alphaRolloutURL.path: try XCTUnwrap(SessionLogParser().sessionMetadata(inFile: alphaRolloutURL)),
                betaRolloutURL.path: try XCTUnwrap(SessionLogParser().sessionMetadata(inFile: betaRolloutURL))
            ],
            currentIdentity: try AuthDecoder().loadActiveAccount(from: authURL),
            observedAt: base.addingTimeInterval(100),
            now: base.addingTimeInterval(300)
        )
        XCTAssertEqual(preflightPlan.activeEmail, "alpha@example.com")
        XCTAssertEqual(preflightPlan.bindings[alphaSessionID]?.email, "alpha@example.com")
        XCTAssertEqual(preflightPlan.bindings[betaSessionID]?.email, "beta@example.com")

        try store.save(
            seededState
        )
        let loadedState = try XCTUnwrap(store.load())
        XCTAssertEqual(loadedState.authObservations.count, 2)

        let viewModel = AppViewModel(
            helloSender: NoopHelloSender(),
            store: store,
            authURL: authURL,
            logsURL: sessionsURL,
            threadDatabaseURL: databaseURL,
            startObservers: false
        )

        try await waitUntil("initial refresh loads alpha as active") {
            viewModel.state.activeEmail == "alpha@example.com"
                && viewModel.state.accounts.first(where: { $0.email == "alpha@example.com" })?.lastSnapshot?.fiveHour.usedPercent == 61.0
                && viewModel.state.accounts.first(where: { $0.email == "beta@example.com" })?.lastSnapshot?.fiveHour.usedPercent == 15.0
        } diagnostics: {
            "active=\(String(describing: viewModel.state.activeEmail)) error=\(String(describing: viewModel.lastError)) bindings=\(Array(viewModel.state.sessionBindings.keys).sorted())"
        }

        XCTAssertEqual(viewModel.state.activeEmail, "alpha@example.com")

        try appendTokenCount(
            to: betaRolloutURL,
            at: base.addingTimeInterval(260),
            primaryUsedPercent: 29.0,
            secondaryUsedPercent: 9.0
        )
        try replaceThreadTimestamp(
            at: databaseURL,
            sessionID: betaSessionID,
            updatedAt: base.addingTimeInterval(250).timeIntervalSince1970
        )

        viewModel.refreshFromLogs(force: true)

        try await waitUntil("forced refresh switches active session to beta") {
            viewModel.state.activeEmail == "beta@example.com"
                && viewModel.state.accounts.first(where: { $0.email == "beta@example.com" })?.lastSnapshot?.fiveHour.usedPercent == 29.0
                && viewModel.state.lastRefresh != nil
        } diagnostics: {
            let betaSnapshot = viewModel.state.accounts.first(where: { $0.email == "beta@example.com" })?.lastSnapshot?.fiveHour.usedPercent
            return "active=\(String(describing: viewModel.state.activeEmail)) error=\(String(describing: viewModel.lastError)) betaSnapshot=\(String(describing: betaSnapshot)) bindings=\(Array(viewModel.state.sessionBindings.keys).sorted())"
        }

        XCTAssertEqual(viewModel.state.activeEmail, "beta@example.com")
        XCTAssertEqual(
            viewModel.state.accounts.first(where: { $0.email == "beta@example.com" })?.lastSnapshot?.fiveHour.usedPercent,
            29.0
        )
        XCTAssertEqual(viewModel.state.sessionBindings[alphaSessionID]?.email, "alpha@example.com")
        XCTAssertEqual(viewModel.state.sessionBindings[betaSessionID]?.email, "beta@example.com")
    }

    private func writeAuthFile(to url: URL, email: String, subject: String, accountId: String) throws {
        let header = #"{"alg":"none","typ":"JWT"}"#
        let payload = #"{"email":"\#(email)","sub":"\#(subject)"}"#
        let token = "\(base64URL(header)).\(base64URL(payload))."
        let auth = """
        {
          "tokens": {
            "id_token": "\(token)",
            "account_id": "\(accountId)"
          }
        }
        """
        try auth.write(to: url, atomically: true, encoding: .utf8)
    }

    private func writeRollout(
        to url: URL,
        sessionID: String,
        startedAt: Date,
        events: [(Date, Double, Double)]
    ) throws {
        let formatter = fractionalISO8601Formatter()
        var lines = [
            """
            {"timestamp":"\(formatter.string(from: startedAt))","type":"session_meta","payload":{"id":"\(sessionID)","timestamp":"\(formatter.string(from: startedAt))","cwd":"/tmp/project","originator":"codex_cli_rs","cli_version":"0.111.0","source":"cli","model_provider":"openai"}}
            """
        ]
        for event in events {
            lines.append(tokenCountLine(
                timestamp: event.0,
                primaryUsedPercent: event.1,
                secondaryUsedPercent: event.2
            ))
        }
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private func appendTokenCount(
        to url: URL,
        at timestamp: Date,
        primaryUsedPercent: Double,
        secondaryUsedPercent: Double
    ) throws {
        let line = tokenCountLine(
            timestamp: timestamp,
            primaryUsedPercent: primaryUsedPercent,
            secondaryUsedPercent: secondaryUsedPercent
        )
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(("\n" + line).utf8))
    }

    private func tokenCountLine(
        timestamp: Date,
        primaryUsedPercent: Double,
        secondaryUsedPercent: Double
    ) -> String {
        let formatter = fractionalISO8601Formatter()
        return """
        {"timestamp":"\(formatter.string(from: timestamp))","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":\(primaryUsedPercent),"window_minutes":300,"resets_at":\(Int(timestamp.addingTimeInterval(3600).timeIntervalSince1970))},"secondary":{"used_percent":\(secondaryUsedPercent),"window_minutes":10080,"resets_at":\(Int(timestamp.addingTimeInterval(7 * 24 * 3600).timeIntervalSince1970))}}}}
        """
    }

    private func createThreadsDatabase(
        at databaseURL: URL,
        rows: [(String, Double, String, String, Int32)]
    ) throws {
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(databaseURL.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }

        let schema = """
        CREATE TABLE threads (
            id TEXT PRIMARY KEY,
            updated_at REAL NOT NULL,
            rollout_path TEXT NOT NULL,
            cwd TEXT NOT NULL,
            archived INTEGER NOT NULL
        );
        """
        XCTAssertEqual(sqlite3_exec(db, schema, nil, nil, nil), SQLITE_OK)
        try insertRows(rows, into: db)
    }

    private func replaceThreadTimestamp(
        at databaseURL: URL,
        sessionID: String,
        updatedAt: Double
    ) throws {
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(databaseURL.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }

        let update = "UPDATE threads SET updated_at = ? WHERE id = ?;"
        var statement: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(db, update, -1, &statement, nil), SQLITE_OK)
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_double(statement, 1, updatedAt)
        sqlite3_bind_text(statement, 2, sessionID, -1, transientDestructor)
        XCTAssertEqual(sqlite3_step(statement), SQLITE_DONE)
    }

    private func insertRows(_ rows: [(String, Double, String, String, Int32)], into db: OpaquePointer?) throws {
        let insert = "INSERT INTO threads (id, updated_at, rollout_path, cwd, archived) VALUES (?, ?, ?, ?, ?);"
        var statement: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(db, insert, -1, &statement, nil), SQLITE_OK)
        defer { sqlite3_finalize(statement) }

        for row in rows {
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
            sqlite3_bind_text(statement, 1, row.0, -1, transientDestructor)
            sqlite3_bind_double(statement, 2, row.1)
            sqlite3_bind_text(statement, 3, row.2, -1, transientDestructor)
            sqlite3_bind_text(statement, 4, row.3, -1, transientDestructor)
            sqlite3_bind_int(statement, 5, row.4)
            XCTAssertEqual(sqlite3_step(statement), SQLITE_DONE)
        }
    }

    private func waitUntil(
        _ description: String,
        timeout: TimeInterval = 3,
        pollInterval: UInt64 = 50_000_000,
        condition: @escaping @MainActor () -> Bool,
        diagnostics: @escaping @MainActor () -> String = { "" }
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return
            }
            try await Task.sleep(nanoseconds: pollInterval)
        }
        XCTFail("\(description) | \(diagnostics())")
    }

    private func base64URL(_ string: String) -> String {
        Data(string.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func fractionalISO8601Formatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }
}

private struct NoopHelloSender: HelloSending {
    func sendHello(modelName: String?, message: String) throws {}
}

private let transientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
