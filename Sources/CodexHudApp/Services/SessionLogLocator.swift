import Foundation

struct SessionLogLocator {
    let logsURL: URL
    private let fileManager: FileManager

    init(logsURL: URL, fileManager: FileManager = .default) {
        self.logsURL = logsURL
        self.fileManager = fileManager
    }

    func latestLogFile() -> URL? {
        guard fileManager.fileExists(atPath: logsURL.path) else { return nil }

        let rootKeys: Set<URLResourceKey> = [.isDirectoryKey, .contentModificationDateKey]
        let childKeys: Set<URLResourceKey> = [.contentModificationDateKey, .isRegularFileKey]

        let rootItems = (try? fileManager.contentsOfDirectory(
            at: logsURL,
            includingPropertiesForKeys: Array(rootKeys),
            options: [.skipsHiddenFiles]
        )) ?? []

        var candidateDirs: [(url: URL, modifiedAt: Date)] = []
        var candidateFiles: [(url: URL, modifiedAt: Date)] = []

        for url in rootItems {
            let values = (try? url.resourceValues(forKeys: rootKeys))
            let modifiedAt = values?.contentModificationDate ?? Date.distantPast
            if values?.isDirectory == true {
                candidateDirs.append((url, modifiedAt))
            } else if url.pathExtension == "jsonl" {
                candidateFiles.append((url, modifiedAt))
            }
        }

        candidateDirs.sort { $0.modifiedAt > $1.modifiedAt }
        candidateFiles.sort { $0.modifiedAt > $1.modifiedAt }

        var newest: (url: URL, modifiedAt: Date)? = candidateFiles.first

        // Typical Codex layout is sessions/<session-id>/rollout-*.jsonl. Scan only the newest few session
        // directories to avoid walking a potentially huge history.
        for dir in candidateDirs.prefix(25) {
            let items = (try? fileManager.contentsOfDirectory(
                at: dir.url,
                includingPropertiesForKeys: Array(childKeys),
                options: [.skipsHiddenFiles]
            )) ?? []
            for file in items where file.pathExtension == "jsonl" {
                let values = (try? file.resourceValues(forKeys: childKeys))
                guard values?.isRegularFile == true else { continue }
                let modifiedAt = values?.contentModificationDate ?? Date.distantPast
                if let current = newest {
                    if modifiedAt > current.modifiedAt { newest = (file, modifiedAt) }
                } else {
                    newest = (file, modifiedAt)
                }
            }
        }

        if newest != nil { return newest?.url }

        // Fallback: recursive search (should be rare).
        let enumerator = fileManager.enumerator(
            at: logsURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        while let item = enumerator?.nextObject() as? URL {
            guard item.pathExtension == "jsonl" else { continue }
            let modifiedAt = (try? item.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
            if let current = newest {
                if modifiedAt > current.modifiedAt { newest = (item, modifiedAt) }
            } else {
                newest = (item, modifiedAt)
            }
        }
        return newest?.url
    }
}

