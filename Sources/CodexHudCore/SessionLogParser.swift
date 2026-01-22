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
        var latest: TokenCountEvent?
        for line in data.split(separator: "\n") {
            guard let event = parseTokenCountLine(String(line)) else { continue }
            if let cutoff, event.timestamp < cutoff { continue }
            if let current = latest {
                if event.timestamp > current.timestamp { latest = event }
            } else {
                latest = event
            }
        }
        return latest
    }

    private func parseTokenCountLine(_ line: String) -> TokenCountEvent? {
        guard line.contains("\"type\":\"event_msg\"") else { return nil }
        guard line.contains("\"token_count\"") else { return nil }
        guard let data = line.data(using: .utf8) else { return nil }
        guard let obj = try? JSONSerialization.jsonObject(with: data),
              let dict = obj as? [String: Any] else { return nil }
        guard let timestampRaw = dict["timestamp"] as? String else { return nil }
        guard let timestamp = parseTimestamp(timestampRaw) else { return nil }
        guard let payload = dict["payload"] as? [String: Any] else { return nil }
        guard let rateLimits = payload["rate_limits"] as? [String: Any] else { return nil }
        let primary = parseRateLimit(rateLimits["primary"])
        let secondary = parseRateLimit(rateLimits["secondary"])
        return TokenCountEvent(timestamp: timestamp, primary: primary, secondary: secondary)
    }

    private func parseTimestamp(_ raw: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: raw) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: raw)
    }

    private func parseRateLimit(_ value: Any?) -> RateLimit? {
        guard let dict = value as? [String: Any] else { return nil }
        guard let usedPercent = number(dict["used_percent"]) else { return nil }
        guard let windowMinutes = number(dict["window_minutes"]) else { return nil }
        guard let resetsAt = number(dict["resets_at"]) else { return nil }
        let resetDate = Date(timeIntervalSince1970: resetsAt)
        return RateLimit(usedPercent: usedPercent, windowMinutes: Int(windowMinutes), resetsAt: resetDate)
    }

    private func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        if let double = value as? Double {
            return double
        }
        if let int = value as? Int {
            return Double(int)
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
