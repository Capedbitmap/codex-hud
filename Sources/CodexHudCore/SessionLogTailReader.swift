import Foundation

public struct SessionLogTailReader: Sendable {
    public let maxBytes: Int

    public init(maxBytes: Int = 256 * 1024) {
        self.maxBytes = maxBytes
    }

    public func latestTokenCountEvent(inFile fileURL: URL, since cutoff: Date?) throws -> TokenCountEvent? {
        let fileSize = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard fileSize > 0 else { return nil }

        let startOffset = max(0, fileSize - maxBytes)
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        try handle.seek(toOffset: UInt64(startOffset))
        let data = try handle.readToEnd() ?? Data()
        if data.isEmpty { return nil }

        let lines = data.split(separator: 0x0A, omittingEmptySubsequences: false)
        let parser = TokenCountEventLineParser()

        let dropFirstLine = startOffset > 0
        let startIndex = dropFirstLine ? 1 : 0
        if startIndex >= lines.count { return nil }

        for rawLine in lines[startIndex...].reversed() {
            guard let line = String(data: rawLine, encoding: .utf8) else { continue }
            guard let event = parser.parseTokenCountEvent(fromLine: line) else { continue }
            if let cutoff, event.timestamp < cutoff {
                return nil
            }
            return event
        }
        return nil
    }
}

public final class SessionLogIncrementalReader {
    private let fileURL: URL
    private var handle: FileHandle?
    private var offset: UInt64
    private var remainder: Data
    private let parser: TokenCountEventLineParser

    public init(fileURL: URL, startingOffset: UInt64) throws {
        self.fileURL = fileURL
        self.handle = try FileHandle(forReadingFrom: fileURL)
        self.remainder = Data()
        self.parser = TokenCountEventLineParser()
        self.offset = startingOffset
    }

    deinit {
        try? handle?.close()
    }

    public func readNewTokenCountEvent(since cutoff: Date?) throws -> TokenCountEvent? {
        guard let handle else { return nil }
        try handle.seek(toOffset: offset)
        let data = try handle.readToEnd() ?? Data()
        offset += UInt64(data.count)

        if data.isEmpty { return nil }

        remainder.append(data)
        var latest: TokenCountEvent?

        while let newlineIndex = remainder.firstIndex(of: 0x0A) {
            let lineData = remainder[..<newlineIndex]
            remainder.removeSubrange(..<remainder.index(after: newlineIndex))
            guard let line = String(data: lineData, encoding: .utf8) else { continue }
            guard let event = parser.parseTokenCountEvent(fromLine: line) else { continue }
            if let cutoff, event.timestamp < cutoff { continue }
            if let current = latest {
                if event.timestamp > current.timestamp { latest = event }
            } else {
                latest = event
            }
        }

        return latest
    }
}
