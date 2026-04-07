import Foundation
import SQLite3

public struct CodexThreadActivity: Equatable, Sendable {
    public let sessionID: String
    public let updatedAt: Date
    public let rolloutPath: String
    public let cwd: String

    public init(sessionID: String, updatedAt: Date, rolloutPath: String, cwd: String) {
        self.sessionID = sessionID
        self.updatedAt = updatedAt
        self.rolloutPath = rolloutPath
        self.cwd = cwd
    }
}

public enum ThreadActivityStoreError: Error, Equatable {
    case databaseOpenFailed
    case statementPrepareFailed
    case queryFailed
}

public struct ThreadActivityStore {
    public let databaseURL: URL

    public init(databaseURL: URL) {
        self.databaseURL = databaseURL
    }

    public func recentThreads(limit: Int) throws -> [CodexThreadActivity] {
        guard limit > 0 else { return [] }

        var db: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(db)
            throw ThreadActivityStoreError.databaseOpenFailed
        }
        defer { sqlite3_close(db) }

        let sql = """
        SELECT id, updated_at, rollout_path, cwd
        FROM threads
        WHERE archived = 0
        ORDER BY updated_at DESC
        LIMIT ?
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            sqlite3_finalize(statement)
            throw ThreadActivityStoreError.statementPrepareFailed
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int(statement, 1, Int32(limit))

        var threads: [CodexThreadActivity] = []
        while true {
            let stepResult = sqlite3_step(statement)
            if stepResult == SQLITE_ROW {
                guard let idPointer = sqlite3_column_text(statement, 0),
                      let rolloutPointer = sqlite3_column_text(statement, 2),
                      let cwdPointer = sqlite3_column_text(statement, 3) else {
                    continue
                }
                let sessionID = String(cString: idPointer)
                let updatedAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 1))
                let rolloutPath = String(cString: rolloutPointer)
                let cwd = String(cString: cwdPointer)
                threads.append(CodexThreadActivity(
                    sessionID: sessionID,
                    updatedAt: updatedAt,
                    rolloutPath: rolloutPath,
                    cwd: cwd
                ))
                continue
            }

            if stepResult == SQLITE_DONE {
                break
            }

            throw ThreadActivityStoreError.queryFailed
        }

        return threads
    }
}
