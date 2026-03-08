import Foundation

struct SessionLogLocator {
    let logsURL: URL
    private let fileManager: FileManager

    init(logsURL: URL, fileManager: FileManager = .default) {
        self.logsURL = logsURL
        self.fileManager = fileManager
    }

    func latestLogFile() -> URL? {
        recentLogFiles(referenceDate: Date(), lookbackDays: 7, limit: 1).first
    }

    func recentLogFiles(referenceDate: Date, lookbackDays: Int, limit: Int) -> [URL] {
        guard fileManager.fileExists(atPath: logsURL.path) else { return [] }
        guard limit > 0 else { return [] }

        let calendar = Calendar(identifier: .gregorian)
        let rootKeys: Set<URLResourceKey> = [.isRegularFileKey, .contentModificationDateKey]
        var collected: [(url: URL, modifiedAt: Date)] = []

        for offset in 0..<max(lookbackDays, 1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: referenceDate) else { continue }
            let components = calendar.dateComponents([.year, .month, .day], from: day)
            guard let year = components.year, let month = components.month, let day = components.day else { continue }
            let dayDirectory = logsURL
                .appendingPathComponent(String(format: "%04d", year), isDirectory: true)
                .appendingPathComponent(String(format: "%02d", month), isDirectory: true)
                .appendingPathComponent(String(format: "%02d", day), isDirectory: true)
            guard fileManager.fileExists(atPath: dayDirectory.path) else { continue }
            let items = (try? fileManager.contentsOfDirectory(
                at: dayDirectory,
                includingPropertiesForKeys: Array(rootKeys),
                options: [.skipsHiddenFiles]
            )) ?? []
            for item in items where item.pathExtension == "jsonl" {
                let values = (try? item.resourceValues(forKeys: rootKeys))
                guard values?.isRegularFile == true else { continue }
                let modifiedAt = values?.contentModificationDate ?? Date.distantPast
                collected.append((item, modifiedAt))
            }
        }

        if collected.isEmpty {
            return fallbackRecentLogFiles(limit: limit)
        }

        return collected
            .sorted { $0.modifiedAt > $1.modifiedAt }
            .prefix(limit)
            .map(\.url)
    }

    private func fallbackRecentLogFiles(limit: Int) -> [URL] {
        let enumerator = fileManager.enumerator(
            at: logsURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        var collected: [(url: URL, modifiedAt: Date)] = []
        while let item = enumerator?.nextObject() as? URL {
            guard item.pathExtension == "jsonl" else { continue }
            let modifiedAt = (try? item.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
            collected.append((item, modifiedAt))
        }
        return collected
            .sorted { $0.modifiedAt > $1.modifiedAt }
            .prefix(limit)
            .map(\.url)
    }
}
