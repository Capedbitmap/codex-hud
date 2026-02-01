import Foundation
import CodexHudCore

actor SessionLogIngestor {
    private let logsURL: URL
    private let tailBytes: Int
    private var currentFile: URL?
    private var reader: SessionLogIncrementalReader?

    init(logsURL: URL, tailBytes: Int) {
        self.logsURL = logsURL
        self.tailBytes = tailBytes
    }

    func refreshLatestLogFile(cutoff: Date?) throws -> TokenCountEvent? {
        let locator = SessionLogLocator(logsURL: logsURL)
        guard let latestFile = locator.latestLogFile() else {
            throw SessionLogError.logsNotFound
        }
        return try ingest(fileURL: latestFile, cutoff: cutoff)
    }

    func ingest(fileURL: URL, cutoff: Date?) throws -> TokenCountEvent? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw SessionLogError.logsNotFound
        }
        if currentFile != fileURL || reader == nil {
            let fileSize = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            let startOffset = UInt64(max(0, fileSize - tailBytes))
            reader = try SessionLogIncrementalReader(fileURL: fileURL, startingOffset: startOffset)
            currentFile = fileURL
        }
        return try reader?.readNewTokenCountEvent(since: cutoff)
    }
}
