import Foundation

final class AuthFileWatcher {
    private let authURL: URL
    private let directoryURL: URL
    private let queue: DispatchQueue
    private let onChange: () -> Void
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var lastModified: Date?

    init(authURL: URL, onChange: @escaping () -> Void) {
        self.authURL = authURL
        self.directoryURL = authURL.deletingLastPathComponent()
        self.queue = DispatchQueue(label: "codex.hud.authwatcher")
        self.onChange = onChange
    }

    func start() {
        stop()
        fileDescriptor = open(directoryURL.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename, .attrib],
            queue: queue
        )

        source?.setEventHandler { [weak self] in
            self?.checkForAuthChange()
        }

        source?.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                close(fd)
            }
            self?.fileDescriptor = -1
        }

        source?.resume()
        checkForAuthChange()
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    private func checkForAuthChange() {
        guard let date = modificationDate() else { return }
        if let last = lastModified, last == date { return }
        lastModified = date
        onChange()
    }

    private func modificationDate() -> Date? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: authURL.path)
            return attributes[.modificationDate] as? Date
        } catch {
            return nil
        }
    }
}
