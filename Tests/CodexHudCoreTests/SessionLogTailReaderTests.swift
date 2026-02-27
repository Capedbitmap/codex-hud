import XCTest
@testable import CodexHudCore

final class SessionLogTailReaderTests: XCTestCase {
    func testTailReaderReturnsLatestTokenCountEvent() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("rollout-1.jsonl")

        let first = tokenCountLine(timestamp: "2025-01-01T00:00:00Z", primaryUsed: 10, secondaryUsed: 20)
        let second = tokenCountLine(timestamp: "2025-01-01T01:00:00Z", primaryUsed: 11, secondaryUsed: 21)
        try (first + "\n" + second + "\n").write(to: file, atomically: true, encoding: .utf8)

        let reader = SessionLogTailReader(maxBytes: 64 * 1024)
        let event = try reader.latestTokenCountEvent(inFile: file, since: nil)

        XCTAssertEqual(event?.timestamp, iso8601().date(from: "2025-01-01T01:00:00Z"))
        XCTAssertEqual(event?.primary?.usedPercent, 11)
        XCTAssertEqual(event?.secondary?.usedPercent, 21)
    }

    func testTailReaderRespectsCutoff() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("rollout-1.jsonl")
        let first = tokenCountLine(timestamp: "2025-01-01T00:00:00Z", primaryUsed: 10, secondaryUsed: 20)
        try (first + "\n").write(to: file, atomically: true, encoding: .utf8)

        let cutoff = iso8601().date(from: "2025-01-01T00:30:00Z")!
        let reader = SessionLogTailReader(maxBytes: 64 * 1024)
        let event = try reader.latestTokenCountEvent(inFile: file, since: cutoff)
        XCTAssertNil(event)
    }

    func testIncrementalReaderReturnsNewerAppendedEvent() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("rollout-1.jsonl")
        let first = tokenCountLine(timestamp: "2025-01-01T00:00:00Z", primaryUsed: 10, secondaryUsed: 20)
        try (first + "\n").write(to: file, atomically: true, encoding: .utf8)

        let reader = try SessionLogIncrementalReader(fileURL: file, startingOffset: 0)
        let firstEvent = try reader.readNewTokenCountEvent(since: nil)
        XCTAssertEqual(firstEvent?.primary?.usedPercent, 10)

        let second = tokenCountLine(timestamp: "2025-01-01T01:00:00Z", primaryUsed: 11, secondaryUsed: 21)
        let handle = try FileHandle(forWritingTo: file)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data((second + "\n").utf8))
        try handle.close()

        let secondEvent = try reader.readNewTokenCountEvent(since: nil)
        XCTAssertEqual(secondEvent?.primary?.usedPercent, 11)
        XCTAssertEqual(secondEvent?.secondary?.usedPercent, 21)
    }

    func testTailReaderSkipsSparkLimitsWhenSparkLineIsNewest() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("rollout-1.jsonl")
        let codex = tokenCountLine(
            timestamp: "2026-02-27T16:00:56Z",
            primaryUsed: 3,
            secondaryUsed: 51,
            limitID: "codex",
            limitName: nil
        )
        let spark = tokenCountLine(
            timestamp: "2026-02-27T16:00:56Z",
            primaryUsed: 0,
            secondaryUsed: 0,
            limitID: "codex_bengalfox",
            limitName: "GPT-5.3-Codex-Spark"
        )
        try (codex + "\n" + spark + "\n").write(to: file, atomically: true, encoding: .utf8)

        let reader = SessionLogTailReader(maxBytes: 64 * 1024)
        let event = try reader.latestTokenCountEvent(inFile: file, since: nil)

        XCTAssertEqual(event?.timestamp, iso8601().date(from: "2026-02-27T16:00:56Z"))
        XCTAssertEqual(event?.primary?.usedPercent, 3)
        XCTAssertEqual(event?.secondary?.usedPercent, 51)
    }

    private func tokenCountLine(
        timestamp: String,
        primaryUsed: Double,
        secondaryUsed: Double,
        limitID: String? = nil,
        limitName: String? = nil
    ) -> String {
        let limitIDField = limitID.map { "\"\($0)\"" } ?? "null"
        let limitNameField = limitName.map { "\"\($0)\"" } ?? "null"
        // `SessionLogParser` only requires `type=event_msg`, a `timestamp`, a `"token_count"` substring,
        // and `payload.rate_limits.{primary,secondary}` with used_percent/window_minutes/resets_at.
        return """
        {"type":"event_msg","timestamp":"\(timestamp)","token_count":{},"payload":{"rate_limits":{"limit_id":\(limitIDField),"limit_name":\(limitNameField),"primary":{"used_percent":\(primaryUsed),"window_minutes":300,"resets_at":1735689600},"secondary":{"used_percent":\(secondaryUsed),"window_minutes":10080,"resets_at":1736294400}}}}
        """
    }

    private func iso8601() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }
}
