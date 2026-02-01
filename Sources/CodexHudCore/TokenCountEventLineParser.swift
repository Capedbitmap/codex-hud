import Foundation

struct TokenCountEventLineParser {
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

    func parseTokenCountEvent(fromLine line: String) -> TokenCountEvent? {
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
        if let date = formatter.date(from: raw) {
            return date
        }
        return fallbackFormatter.date(from: raw)
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
}

