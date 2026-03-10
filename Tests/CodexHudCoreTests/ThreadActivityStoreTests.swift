import XCTest
import SQLite3
@testable import CodexHudCore

final class ThreadActivityStoreTests: XCTestCase {
    func testReturnsRecentNonArchivedThreadsInUpdatedOrder() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let databaseURL = tempDir.appendingPathComponent("state_5.sqlite")
        try createDatabase(at: databaseURL, rows: [
            ("session-1", 1_762_000_100.0, "/tmp/one.jsonl", "/tmp/one", 0),
            ("session-2", 1_762_000_300.0, "/tmp/two.jsonl", "/tmp/two", 0),
            ("session-archived", 1_762_000_500.0, "/tmp/archived.jsonl", "/tmp/archived", 1)
        ])

        let store = ThreadActivityStore(databaseURL: databaseURL)
        let threads = try store.recentThreads(limit: 10)

        XCTAssertEqual(threads.map(\.sessionID), ["session-2", "session-1"])
        XCTAssertEqual(threads.first?.rolloutPath, "/tmp/two.jsonl")
    }

    private func createDatabase(at databaseURL: URL, rows: [(String, Double, String, String, Int32)]) throws {
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
}

private let transientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
