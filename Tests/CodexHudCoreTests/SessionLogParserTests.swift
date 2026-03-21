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

    func testLatestTokenCountEventSkipsRecentUnparseableFile() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let staleFile = tempDir.appendingPathComponent("stale.jsonl")
        let activeFile = tempDir.appendingPathComponent("active.jsonl")

        let staleLine = "{\"timestamp\":\"2026-03-01T07:00:00Z\",\"type\":\"event_msg\",\"payload\":{\"type\":\"token_count\",\"rate_limits\":{\"limit_id\":\"codex\",\"primary\":{\"used_percent\":12.0,\"window_minutes\":300,\"resets_at\":1769000000},\"secondary\":{\"used_percent\":44.0,\"window_minutes\":10080,\"resets_at\":1769600000}}}}\n"
        let activeLine = "{\"timestamp\":\"2026-03-01T08:00:00Z\",\"type\":\"event_msg\",\"payload\":{\"type\":\"message\"}}\n"

        try staleLine.write(to: staleFile, atomically: true, encoding: .utf8)
        try activeLine.write(to: activeFile, atomically: true, encoding: .utf8)

        let oldDate = Date(timeIntervalSince1970: 1)
        let recentDate = Date(timeIntervalSince1970: 2)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: staleFile.path)
        try FileManager.default.setAttributes([.modificationDate: recentDate], ofItemAtPath: activeFile.path)

        let parser = SessionLogParser()
        let event = try parser.latestTokenCountEvent(in: tempDir)

        XCTAssertEqual(event.timestamp, iso8601().date(from: "2026-03-01T07:00:00Z"))
        XCTAssertEqual(event.primary?.usedPercent, 12.0)
        XCTAssertEqual(event.secondary?.usedPercent, 44.0)
    }

    func testParsesSessionMetadataFromCurrentRolloutHeader() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("rollout.jsonl")
        let content = [
            #"{"timestamp":"2026-03-08T06:38:57.764Z","type":"session_meta","payload":{"id":"019ccc2b-a2e3-7bd0-8a2f-1830caac8366","timestamp":"2026-03-08T06:38:57.764Z","cwd":"/tmp/project","originator":"codex_cli_rs","cli_version":"0.111.0","source":"cli","model_provider":"openai"}}"#,
            #"{"timestamp":"2026-03-08T06:46:12.504Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":2.0,"window_minutes":300,"resets_at":1772969892},"secondary":{"used_percent":1.0,"window_minutes":10080,"resets_at":1773556692}}}}"#
        ].joined(separator: "\n")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let parser = SessionLogParser()
        let metadata = try parser.sessionMetadata(inFile: fileURL)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        XCTAssertEqual(metadata?.sessionID, "019ccc2b-a2e3-7bd0-8a2f-1830caac8366")
        XCTAssertEqual(metadata?.cwd, "/tmp/project")
        XCTAssertEqual(metadata?.startedAt, formatter.date(from: "2026-03-08T06:38:57.764Z"))
    }

    func testParsesSessionMetadataWhenHeaderLineExceedsLegacyChunkLimit() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("rollout.jsonl")
        let largeInstruction = String(repeating: "x", count: 20_000)
        let line = """
        {"timestamp":"2026-03-20T12:00:00.000Z","type":"session_meta","payload":{"id":"session-long-header","timestamp":"2026-03-20T12:00:00.000Z","cwd":"/tmp/project","originator":"codex_cli_rs","cli_version":"0.116.0","source":"cli","model_provider":"openai","base_instructions":{"text":"\(largeInstruction)"}}}
        """
        XCTAssertGreaterThan(line.utf8.count, 16 * 1024)
        let content = [
            line,
            #"{"timestamp":"2026-03-20T12:01:00.000Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":10.0,"window_minutes":300,"resets_at":1773970800},"secondary":{"used_percent":20.0,"window_minutes":10080,"resets_at":1774575600}}}}"#
        ].joined(separator: "\n")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let parser = SessionLogParser()
        let metadata = try parser.sessionMetadata(inFile: fileURL)

        XCTAssertEqual(metadata?.sessionID, "session-long-header")
        XCTAssertEqual(metadata?.cwd, "/tmp/project")
    }

    private func iso8601() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }
}
