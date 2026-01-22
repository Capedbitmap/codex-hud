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

    public static func defaultStore(appIdentifier: String = "com.mustafa.codexhud") throws -> AppStateStore {
        let fm = FileManager.default
        guard let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw StorageError.directoryUnavailable
        }
        let dir = base.appendingPathComponent(appIdentifier, isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let fileURL = dir.appendingPathComponent("state.json")
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
            let data = try JSONEncoder.codex.encode(state)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            throw StorageError.failedToWrite
        }
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
