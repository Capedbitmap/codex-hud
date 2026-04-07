import Foundation
import CodexHudCore

actor SessionLogIngestor {
    private let logsURL: URL
    private let tailBytes: Int
    private let parser = SessionLogParser()
    private let tailReader: SessionLogTailReader

    init(logsURL: URL, tailBytes: Int) {
        self.logsURL = logsURL
        self.tailBytes = tailBytes
        self.tailReader = SessionLogTailReader(maxBytes: tailBytes)
    }

    func recentLogFiles(referenceDate: Date = Date(), lookbackDays: Int, limit: Int) -> [URL] {
        SessionLogLocator(logsURL: logsURL).recentLogFiles(referenceDate: referenceDate, lookbackDays: lookbackDays, limit: limit)
    }

    func sessionMetadata(in fileURL: URL) throws -> SessionMetadata? {
        try parser.sessionMetadata(inFile: fileURL)
    }

    func latestTokenCountEvent(in fileURL: URL, since cutoff: Date?) throws -> TokenCountEvent? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw SessionLogError.logsNotFound
        }
        return try tailReader.latestTokenCountEvent(inFile: fileURL, since: cutoff)
    }
}
