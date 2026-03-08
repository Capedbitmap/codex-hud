import Foundation

public struct SessionMetadata: Equatable, Sendable {
    public let sessionID: String
    public let startedAt: Date
    public let cwd: String?
}

public struct RateLimit: Equatable, Sendable {
    public let usedPercent: Double
    public let windowMinutes: Int
    public let resetsAt: Date
}

public struct TokenCountEvent: Equatable, Sendable {
    public let timestamp: Date
    public let primary: RateLimit?
    public let secondary: RateLimit?
}

public enum SessionLogError: Error, Equatable {
    case logsNotFound
    case noTokenCountEvents
    case invalidPayload
}

public struct SessionLogParser {
    public init() {}

    public func latestTokenCountEvent(in logsRoot: URL) throws -> TokenCountEvent {
        try latestTokenCountEvent(in: logsRoot, since: nil)
    }

    public func latestTokenCountEvent(in logsRoot: URL, since cutoff: Date?) throws -> TokenCountEvent {
        guard FileManager.default.fileExists(atPath: logsRoot.path) else {
            throw SessionLogError.logsNotFound
        }
        let files = try jsonlFilesSortedByModificationDate(root: logsRoot)
        var best: TokenCountEvent?
        for file in files {
            if let event = try latestTokenCountEvent(inFile: file, since: cutoff) {
                if let current = best {
                    if event.timestamp > current.timestamp { best = event }
                } else {
                    best = event
                }
            }
        }
        if let best { return best }
        throw SessionLogError.noTokenCountEvents
    }

    public func latestTokenCountEvent(inFile file: URL, since cutoff: Date?) throws -> TokenCountEvent? {
        let data = try String(contentsOf: file, encoding: .utf8)
        let lines = data.split(separator: "\n")
        let parser = TokenCountEventLineParser()
        for line in lines.reversed() {
            guard let event = parser.parseTokenCountEvent(fromLine: String(line)) else { continue }
            if let cutoff, event.timestamp < cutoff {
                return nil
            }
            return event
        }
        return nil
    }

    public func sessionMetadata(inFile file: URL) throws -> SessionMetadata? {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }

        let header = try handle.read(upToCount: 16 * 1024) ?? Data()
        guard !header.isEmpty else { return nil }
        let lines = header.split(separator: 0x0A, omittingEmptySubsequences: false)
        let parser = SessionMetaLineParser()

        for rawLine in lines {
            guard let line = String(data: rawLine, encoding: .utf8) else { continue }
            if let metadata = parser.parseSessionMetadata(fromLine: line) {
                return metadata
            }
        }

        return nil
    }

    private func jsonlFilesSortedByModificationDate(root: URL) throws -> [URL] {
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])
        var files: [URL] = []
        while let item = enumerator?.nextObject() as? URL {
            if item.pathExtension == "jsonl" {
                files.append(item)
            }
        }
        return try files.sorted { lhs, rhs in
            let lhsDate = try lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? Date.distantPast
            let rhsDate = try rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? Date.distantPast
            return lhsDate > rhsDate
        }
    }

}

private struct SessionMetaLineParser {
    private let formatter: ISO8601DateFormatter
    private let fallbackFormatter: ISO8601DateFormatter

    init() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.formatter = formatter

        let fallbackFormatter = ISO8601DateFormatter()
        fallbackFormatter.formatOptions = [.withInternetDateTime]
        self.fallbackFormatter = fallbackFormatter
    }

    func parseSessionMetadata(fromLine line: String) -> SessionMetadata? {
        guard line.contains("\"type\":\"session_meta\"") else { return nil }
        guard let data = line.data(using: .utf8) else { return nil }
        guard let obj = try? JSONSerialization.jsonObject(with: data),
              let dict = obj as? [String: Any],
              let payload = dict["payload"] as? [String: Any],
              let sessionID = payload["id"] as? String,
              let timestampRaw = payload["timestamp"] as? String,
              let startedAt = parseTimestamp(timestampRaw) else {
            return nil
        }
        let cwd = payload["cwd"] as? String
        return SessionMetadata(sessionID: sessionID, startedAt: startedAt, cwd: cwd)
    }

    private func parseTimestamp(_ raw: String) -> Date? {
        if let date = formatter.date(from: raw) {
            return date
        }
        return fallbackFormatter.date(from: raw)
    }
}
