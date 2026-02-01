import Foundation

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

    private func latestTokenCountEvent(inFile file: URL, since cutoff: Date?) throws -> TokenCountEvent? {
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
