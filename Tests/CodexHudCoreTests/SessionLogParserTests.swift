import XCTest
@testable import CodexHudCore

final class SessionLogParserTests: XCTestCase {
    func testParsesLatestTokenCountEvent() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("sample.jsonl")
        let content = [
            "{\"timestamp\":\"2026-01-22T08:30:12.000Z\",\"type\":\"event_msg\",\"payload\":{\"type\":\"token_count\",\"rate_limits\":{\"primary\":{\"used_percent\":42.0,\"window_minutes\":300,\"resets_at\":1769079957},\"secondary\":{\"used_percent\":88.0,\"window_minutes\":10080,\"resets_at\":1769415994}}}}",
            "{\"timestamp\":\"2026-01-22T08:40:12.000Z\",\"type\":\"event_msg\",\"payload\":{\"type\":\"token_count\",\"rate_limits\":{\"primary\":{\"used_percent\":74.0,\"window_minutes\":300,\"resets_at\":1769079957},\"secondary\":{\"used_percent\":91.0,\"window_minutes\":10080,\"resets_at\":1769415994}}}}"
        ].joined(separator: "\n")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let parser = SessionLogParser()
        let event = try parser.latestTokenCountEvent(in: tempDir)
        XCTAssertEqual(event.primary?.usedPercent, 74.0)
        XCTAssertEqual(event.secondary?.usedPercent, 91.0)
        XCTAssertEqual(event.primary?.windowMinutes, 300)
        XCTAssertEqual(event.secondary?.windowMinutes, 10080)
    }

    func testFiltersTokenCountEventsByCutoff() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("sample.jsonl")
        let content = [
            "{\"timestamp\":\"2026-01-22T08:30:12.000Z\",\"type\":\"event_msg\",\"payload\":{\"type\":\"token_count\",\"rate_limits\":{\"primary\":{\"used_percent\":10.0,\"window_minutes\":300,\"resets_at\":1769079957},\"secondary\":{\"used_percent\":20.0,\"window_minutes\":10080,\"resets_at\":1769415994}}}}",
            "{\"timestamp\":\"2026-01-22T08:40:12.000Z\",\"type\":\"event_msg\",\"payload\":{\"type\":\"token_count\",\"rate_limits\":{\"primary\":{\"used_percent\":30.0,\"window_minutes\":300,\"resets_at\":1769079957},\"secondary\":{\"used_percent\":40.0,\"window_minutes\":10080,\"resets_at\":1769415994}}}}"
        ].joined(separator: "\n")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let cutoff = try XCTUnwrap(formatter.date(from: "2026-01-22T08:35:00.000Z"))

        let parser = SessionLogParser()
        let event = try parser.latestTokenCountEvent(in: tempDir, since: cutoff)
        XCTAssertEqual(event.primary?.usedPercent, 30.0)
        XCTAssertEqual(event.secondary?.usedPercent, 40.0)
    }

    func testSkipsSparkRateLimitEntriesAndUsesMainCodexLimit() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("sample.jsonl")
        let codexLine = """
        {"timestamp":"2026-01-22T08:40:12.000Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","limit_name":null,"primary":{"used_percent":74.0,"window_minutes":300,"resets_at":1769079957},"secondary":{"used_percent":91.0,"window_minutes":10080,"resets_at":1769415994}}}}
        """
        let sparkLine = """
        {"timestamp":"2026-01-22T08:41:12.000Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex_bengalfox","limit_name":"GPT-5.3-Codex-Spark","primary":{"used_percent":0.0,"window_minutes":300,"resets_at":1769079999},"secondary":{"used_percent":0.0,"window_minutes":10080,"resets_at":1769416999}}}}
        """
        try (codexLine + "\n" + sparkLine).write(to: fileURL, atomically: true, encoding: .utf8)

        let parser = SessionLogParser()
        let event = try parser.latestTokenCountEvent(in: tempDir)
        XCTAssertEqual(event.timestamp, iso8601().date(from: "2026-01-22T08:40:12Z"))
        XCTAssertEqual(event.primary?.usedPercent, 74.0)
        XCTAssertEqual(event.secondary?.usedPercent, 91.0)
    }

    private func iso8601() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }
}
