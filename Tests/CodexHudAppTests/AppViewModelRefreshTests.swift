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

    func testRefreshInfersFiveHourResetFromNewerActivityWhenRateLimitsAreMissing() async throws {
        let sandbox = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: sandbox) }

        let sessionsURL = sandbox.appendingPathComponent("sessions", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionsURL, withIntermediateDirectories: true)
        let authURL = sandbox.appendingPathComponent("auth.json")
        let databaseURL = sandbox.appendingPathComponent("state_5.sqlite")
        let store = AppStateStore(fileURL: sandbox.appendingPathComponent("state.json"))

        let base = Date().addingTimeInterval(-300)
        let sessionID = "session-alpha"
        let rolloutURL = sessionsURL.appendingPathComponent("alpha.jsonl")

        try writeAuthFile(
            to: authURL,
            email: "alpha@example.com",
            subject: "sub-alpha",
            accountId: "acct-alpha"
        )
        try writeRollout(
            to: rolloutURL,
            sessionID: sessionID,
            startedAt: base.addingTimeInterval(-120),
            events: [],
            includeNullRateLimitEventAt: base
        )
        try createThreadsDatabase(
            at: databaseURL,
            rows: [(sessionID, base.timeIntervalSince1970, rolloutURL.path, "/tmp/alpha", 0)]
        )

        let staleSnapshot = RateLimitsSnapshot(
            capturedAt: base.addingTimeInterval(-8 * 3600),
            fiveHour: UsageWindow(
                kind: .fiveHour,
                usedPercent: 21,
                windowMinutes: 300,
                resetsAt: base.addingTimeInterval(-3 * 3600),
                isStale: false,
                assumedReset: false
            ),
            weekly: UsageWindow(
                kind: .weekly,
                usedPercent: 40,
                windowMinutes: 10080,
                resetsAt: base.addingTimeInterval(4 * 24 * 3600),
                isStale: false,
                assumedReset: false
            ),
            source: .sessionLog
        )

        try store.save(
            AppState(
                accounts: [AccountRecord(codexNumber: 1, email: "alpha@example.com", displayName: nil, lastSnapshot: staleSnapshot, lastUpdated: nil)],
                activeEmail: "alpha@example.com",
                lastRefresh: nil,
                authObservations: [
                    AuthObservation(email: "alpha@example.com", subject: "sub-alpha", accountId: "acct-alpha", observedAt: base.addingTimeInterval(-180))
                ]
            )
        )

        let viewModel = AppViewModel(
            helloSender: NoopHelloSender(),
            store: store,
            authURL: authURL,
            logsURL: sessionsURL,
            threadDatabaseURL: databaseURL,
            startObservers: false
        )

        try await waitUntil("refresh infers five-hour reset from newer thread activity") {
            guard let snapshot = viewModel.state.accounts.first?.lastSnapshot else { return false }
            return snapshot.fiveHour.assumedReset
                && snapshot.fiveHour.isStale
                && snapshot.fiveHour.usedPercent == 0
                && abs(snapshot.fiveHour.resetsAt.timeIntervalSince(base.addingTimeInterval(300 * 60))) < 1
                && snapshot.weekly.usedPercent == 40
        } diagnostics: {
            "active=\(String(describing: viewModel.state.activeEmail)) snapshot=\(String(describing: viewModel.state.accounts.first?.lastSnapshot)) bindings=\(viewModel.state.sessionBindings)"
        }
    }

    func testManualRefreshInvokesForcedRefreshPathWhenSnapshotIsAssumed() async throws {
        let sandbox = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: sandbox) }

        let sessionsURL = sandbox.appendingPathComponent("sessions", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionsURL, withIntermediateDirectories: true)
        let authURL = sandbox.appendingPathComponent("auth.json")
        let databaseURL = sandbox.appendingPathComponent("state_5.sqlite")
        let store = AppStateStore(fileURL: sandbox.appendingPathComponent("state.json"))
        let helloSender = RecordingHelloSender()

        try writeAuthFile(
            to: authURL,
            email: "alpha@example.com",
            subject: "sub-alpha",
            accountId: "acct-alpha"
        )
        try createThreadsDatabase(at: databaseURL, rows: [])

        let assumedSnapshot = RateLimitsSnapshot(
            capturedAt: Date(),
            fiveHour: UsageWindow(kind: .fiveHour, usedPercent: 0, windowMinutes: 300, resetsAt: Date().addingTimeInterval(60), isStale: true, assumedReset: true),
            weekly: UsageWindow(kind: .weekly, usedPercent: 15, windowMinutes: 10080, resetsAt: Date().addingTimeInterval(5 * 24 * 3600), isStale: false, assumedReset: false),
            source: .sessionLog
        )

        try store.save(
            AppState(
                accounts: [AccountRecord(codexNumber: 1, email: "alpha@example.com", displayName: nil, lastSnapshot: assumedSnapshot, lastUpdated: nil)],
                activeEmail: "alpha@example.com",
                lastRefresh: nil
            )
        )

        let viewModel = AppViewModel(
            helloSender: helloSender,
            store: store,
            authURL: authURL,
            logsURL: sessionsURL,
            threadDatabaseURL: databaseURL,
            startObservers: false
        )

        viewModel.manualRefresh()

        try await waitUntil("manual refresh triggers forced refresh path") {
            helloSender.callCount == 1
        }
    }

    func testRefreshRebindsSharedSessionToLatestAuthObservation() async throws {
        let sandbox = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: sandbox) }

        let sessionsURL = sandbox.appendingPathComponent("sessions", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionsURL, withIntermediateDirectories: true)
        let authURL = sandbox.appendingPathComponent("auth.json")
        let databaseURL = sandbox.appendingPathComponent("state_5.sqlite")
        let store = AppStateStore(fileURL: sandbox.appendingPathComponent("state.json"))

        let base = Date().addingTimeInterval(-600)
        let sharedSessionID = "session-shared"
        let sharedRolloutURL = sessionsURL.appendingPathComponent("shared.jsonl")

        try writeAuthFile(
            to: authURL,
            email: "beta@example.com",
            subject: "sub-beta",
            accountId: "acct-beta"
        )
        try writeRollout(
            to: sharedRolloutURL,
            sessionID: sharedSessionID,
            startedAt: base.addingTimeInterval(10),
            events: [(base.addingTimeInterval(80), 11.0, 2.0), (base.addingTimeInterval(140), 44.0, 8.0)]
        )
        try createThreadsDatabase(
            at: databaseURL,
            rows: [(sharedSessionID, base.addingTimeInterval(150).timeIntervalSince1970, sharedRolloutURL.path, "/tmp/shared", 0)]
        )

        let alphaSnapshot = RateLimitsSnapshot(
            capturedAt: base.addingTimeInterval(70),
            fiveHour: UsageWindow(kind: .fiveHour, usedPercent: 11, windowMinutes: 300, resetsAt: base.addingTimeInterval(300), isStale: false, assumedReset: false),
            weekly: UsageWindow(kind: .weekly, usedPercent: 2, windowMinutes: 10080, resetsAt: base.addingTimeInterval(7 * 24 * 3600), isStale: false, assumedReset: false),
            source: .sessionLog
        )

        try store.save(
            AppState(
                accounts: [
                    AccountRecord(codexNumber: 1, email: "alpha@example.com", displayName: nil, lastSnapshot: alphaSnapshot, lastUpdated: nil),
                    AccountRecord(codexNumber: 2, email: "beta@example.com", displayName: nil, lastSnapshot: nil, lastUpdated: nil)
                ],
                activeEmail: "alpha@example.com",
                lastRefresh: nil,
                sessionBindings: [
                    sharedSessionID: SessionAccountBinding(
                        sessionID: sharedSessionID,
                        rolloutPath: sharedRolloutURL.path,
                        email: "alpha@example.com",
                        subject: "sub-alpha",
                        accountId: "acct-alpha",
                        startedAt: base.addingTimeInterval(10),
                        lastObservedAt: base.addingTimeInterval(70)
                    )
                ],
                authObservations: [
                    AuthObservation(email: "alpha@example.com", subject: "sub-alpha", accountId: "acct-alpha", observedAt: base),
                    AuthObservation(email: "beta@example.com", subject: "sub-beta", accountId: "acct-beta", observedAt: base.addingTimeInterval(120))
                ]
            )
        )

        let viewModel = AppViewModel(
            helloSender: NoopHelloSender(),
            store: store,
            authURL: authURL,
            logsURL: sessionsURL,
            threadDatabaseURL: databaseURL,
            startObservers: false
        )

        try await waitUntil("refresh rebinds shared session to beta") {
            viewModel.state.activeEmail == "beta@example.com"
                && viewModel.state.sessionBindings[sharedSessionID]?.email == "beta@example.com"
                && viewModel.state.accounts.first(where: { $0.email == "beta@example.com" })?.lastSnapshot?.fiveHour.usedPercent == 44.0
        } diagnostics: {
            let bindingEmail = viewModel.state.sessionBindings[sharedSessionID]?.email ?? "<missing>"
            let betaSnapshot = viewModel.state.accounts.first(where: { $0.email == "beta@example.com" })?.lastSnapshot?.fiveHour.usedPercent
            return "active=\(String(describing: viewModel.state.activeEmail)) binding=\(bindingEmail) betaSnapshot=\(String(describing: betaSnapshot))"
        }
    }

    func testRefreshFallsBackToRecentRolloutFilesWhenThreadStoreIsStale() async throws {
        let sandbox = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: sandbox) }

        let sessionsURL = sandbox.appendingPathComponent("sessions", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionsURL, withIntermediateDirectories: true)
        let authURL = sandbox.appendingPathComponent("auth.json")
        let databaseURL = sandbox.appendingPathComponent("state_5.sqlite")
        let store = AppStateStore(fileURL: sandbox.appendingPathComponent("state.json"))

        let base = Date().addingTimeInterval(-1200)
        let staleSessionID = "session-stale"
        let freshSessionID = "session-fresh"
        let staleRolloutURL = sessionsURL.appendingPathComponent("stale.jsonl")
        let freshRolloutURL = sessionsURL.appendingPathComponent("fresh.jsonl")

        try writeAuthFile(
            to: authURL,
            email: "beta@example.com",
            subject: "sub-beta",
            accountId: "acct-beta"
        )
        try writeRollout(
            to: staleRolloutURL,
            sessionID: staleSessionID,
            startedAt: base.addingTimeInterval(10),
            events: [(base.addingTimeInterval(20), 5.0, 1.0)]
        )
        try writeRollout(
            to: freshRolloutURL,
            sessionID: freshSessionID,
            startedAt: base.addingTimeInterval(900),
            events: [(base.addingTimeInterval(930), 33.0, 7.0)]
        )
        try createThreadsDatabase(
            at: databaseURL,
            rows: [(staleSessionID, base.addingTimeInterval(30).timeIntervalSince1970, staleRolloutURL.path, "/tmp/stale", 0)]
        )

        try store.save(
            AppState(
                accounts: [AccountRecord(codexNumber: 1, email: "beta@example.com", displayName: nil, lastSnapshot: nil, lastUpdated: nil)],
                activeEmail: nil,
                lastRefresh: nil,
                authObservations: [
                    AuthObservation(email: "beta@example.com", subject: "sub-beta", accountId: "acct-beta", observedAt: base)
                ]
            )
        )

        let viewModel = AppViewModel(
            helloSender: NoopHelloSender(),
            store: store,
            authURL: authURL,
            logsURL: sessionsURL,
            threadDatabaseURL: databaseURL,
            startObservers: false
        )

        try await waitUntil("refresh uses fresh rollout file when thread DB is stale") {
            viewModel.state.activeEmail == "beta@example.com"
                && viewModel.state.sessionBindings[freshSessionID]?.email == "beta@example.com"
                && viewModel.state.accounts.first?.lastSnapshot?.fiveHour.usedPercent == 33.0
        } diagnostics: {
            let active = viewModel.state.activeEmail ?? "<nil>"
            let freshBinding = viewModel.state.sessionBindings[freshSessionID]?.email ?? "<missing>"
            let snapshot = viewModel.state.accounts.first?.lastSnapshot?.fiveHour.usedPercent
            return "active=\(active) freshBinding=\(freshBinding) snapshot=\(String(describing: snapshot)) bindings=\(viewModel.state.sessionBindings)"
        }
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
        events: [(Date, Double, Double)],
        includeNullRateLimitEventAt nullRateLimitTimestamp: Date? = nil
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
        if let nullRateLimitTimestamp {
            lines.append(nullRateLimitLine(timestamp: nullRateLimitTimestamp))
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

    private func nullRateLimitLine(timestamp: Date) -> String {
        let formatter = fractionalISO8601Formatter()
        return """
        {"timestamp":"\(formatter.string(from: timestamp))","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":100,"cached_input_tokens":0,"output_tokens":1,"reasoning_output_tokens":0,"total_tokens":101},"last_token_usage":{"input_tokens":100,"cached_input_tokens":0,"output_tokens":1,"reasoning_output_tokens":0,"total_tokens":101},"model_context_window":258400},"rate_limits":null}}
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

private final class RecordingHelloSender: HelloSending {
    private(set) var callCount = 0

    func sendHello(modelName: String?, message: String) throws {
        callCount += 1
    }
}

private let transientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
