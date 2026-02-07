import Foundation

public enum StorageError: Error, Equatable {
    case directoryUnavailable
    case failedToWrite
    case failedToRead
}

public struct AppStateStore {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static func defaultStore(appIdentifier: String? = nil) throws -> AppStateStore {
        let fm = FileManager.default
        guard let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw StorageError.directoryUnavailable
        }
        let resolvedIdentifier = appIdentifier ?? Bundle.main.bundleIdentifier ?? "io.github.capedbitmap.codexhud"
        let dir = base.appendingPathComponent(resolvedIdentifier, isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let fileURL = dir.appendingPathComponent("state.json")
        try StorageMigration.migrateStateIfNeeded(into: fileURL, baseDirectory: base, preferredIdentifier: resolvedIdentifier)
        return AppStateStore(fileURL: fileURL)
    }

    public func load() throws -> AppState? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder.codex.decode(AppState.self, from: data)
        } catch {
            throw StorageError.failedToRead
        }
    }

    public func save(_ state: AppState) throws {
        do {
            try StorageBackup.maybeBackupExistingStateFile(at: fileURL, newAccountCount: state.accounts.count)
            let data = try JSONEncoder.codex.encode(state)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            throw StorageError.failedToWrite
        }
    }
}

private enum StorageBackup {
    private static let maxBackupsToKeep = 5
    private static let minimumBackupInterval: TimeInterval = 6 * 60 * 60

    static func maybeBackupExistingStateFile(at fileURL: URL, newAccountCount: Int) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else { return }

        let existingAccountCount = StorageMigration.stateAccountCount(at: fileURL) ?? 0
        let isAccountDecrease = existingAccountCount > newAccountCount

        if !isAccountDecrease {
            if let mostRecent = mostRecentBackupDate(for: fileURL),
               Date().timeIntervalSince(mostRecent) < minimumBackupInterval {
                return
            }
        }

        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backupURL = fileURL
            .deletingLastPathComponent()
            .appendingPathComponent("state.json.bak.\(timestamp)")

        try? fm.copyItem(at: fileURL, to: backupURL)
        pruneOldBackups(for: fileURL, keep: maxBackupsToKeep)
    }

    private static func mostRecentBackupDate(for fileURL: URL) -> Date? {
        let fm = FileManager.default
        let dir = fileURL.deletingLastPathComponent()
        let items = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])) ?? []
        let backups = items.filter { $0.lastPathComponent.hasPrefix("state.json.bak.") }
        let dates = backups.compactMap { (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) }
        return dates.max()
    }

    private static func pruneOldBackups(for fileURL: URL, keep: Int) {
        let fm = FileManager.default
        let dir = fileURL.deletingLastPathComponent()
        let items = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])) ?? []
        let backups = items
            .filter { $0.lastPathComponent.hasPrefix("state.json.bak.") }
            .sorted { lhs, rhs in
                let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                return lhsDate > rhsDate
            }
        guard backups.count > keep else { return }
        for url in backups.suffix(from: keep) {
            try? fm.removeItem(at: url)
        }
    }
}

private enum StorageMigration {
    static func migrateStateIfNeeded(into targetFile: URL, baseDirectory: URL, preferredIdentifier: String) throws {
        let fm = FileManager.default

        let legacyFiles = discoverLegacyStateFiles(baseDirectory: baseDirectory, preferredIdentifier: preferredIdentifier)

        let targetExists = fm.fileExists(atPath: targetFile.path)
        let targetAccounts = targetExists ? (stateAccountCount(at: targetFile) ?? 0) : 0

        var best: (url: URL, modifiedAt: Date, accounts: Int)?
        for legacyFile in legacyFiles {
            guard fm.fileExists(atPath: legacyFile.path) else { continue }
            let accounts = stateAccountCount(at: legacyFile) ?? 0
            let modifiedAt = (try? legacyFile.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
            if let current = best {
                let prefer = accounts > current.accounts || (accounts == current.accounts && modifiedAt > current.modifiedAt)
                if prefer { best = (legacyFile, modifiedAt, accounts) }
            } else {
                best = (legacyFile, modifiedAt, accounts)
            }
        }

        guard let best else { return }

        // If the target already exists but appears unconfigured, prefer a legacy file that has accounts.
        if targetExists, targetAccounts == 0, best.accounts > 0 {
            try backupStateFile(targetFile)
            try fm.removeItem(at: targetFile)
            try fm.copyItem(at: best.url, to: targetFile)
            return
        }

        // If target doesn't exist, migrate the best legacy file (even if empty) to keep continuity.
        if !targetExists {
            try fm.createDirectory(at: targetFile.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.copyItem(at: best.url, to: targetFile)
        }
    }

    private static func backupStateFile(_ fileURL: URL) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else { return }
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backup = fileURL.deletingLastPathComponent().appendingPathComponent("state.json.bak.\(timestamp)")
        try? fm.copyItem(at: fileURL, to: backup)
    }

    fileprivate static func stateAccountCount(at fileURL: URL) -> Int? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        guard let obj = try? JSONSerialization.jsonObject(with: data),
              let dict = obj as? [String: Any] else { return nil }
        let accounts = dict["accounts"] as? [Any]
        return accounts?.count
    }

    private static func discoverLegacyStateFiles(baseDirectory: URL, preferredIdentifier: String) -> [URL] {
        let fm = FileManager.default
        let identifierMatches = (try? fm.contentsOfDirectory(at: baseDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]))?
            .filter { $0.hasDirectoryPath }
            .filter { $0.lastPathComponent != preferredIdentifier }
            .filter { $0.lastPathComponent.lowercased().contains("codexhud") || $0.lastPathComponent.lowercased().contains("codex-hud") } ?? []

        return identifierMatches.map { $0.appendingPathComponent("state.json") }
    }
}

private extension JSONEncoder {
    static let codex: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

private extension JSONDecoder {
    static let codex: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
