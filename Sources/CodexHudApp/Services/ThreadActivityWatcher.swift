import Foundation

final class ThreadActivityWatcher {
    private let fileURLs: [URL]
    private let queue: DispatchQueue
    private let onChange: () -> Void
    private var sources: [DispatchSourceFileSystemObject] = []
    private var descriptors: [Int32] = []
    private var lastModifiedByPath: [String: Date] = [:]

    init(fileURLs: [URL], onChange: @escaping () -> Void) {
        self.fileURLs = fileURLs
        self.queue = DispatchQueue(label: "codex.hud.threadactivity")
        self.onChange = onChange
    }

    func start() {
        stop()
        for fileURL in fileURLs where FileManager.default.fileExists(atPath: fileURL.path) {
            startWatcher(for: fileURL)
            cacheModificationDate(for: fileURL)
        }
        if !sources.isEmpty {
            onChange()
        }
    }

    func stop() {
        for source in sources {
            source.cancel()
        }
        sources.removeAll()
        descriptors.removeAll()
    }

    private func startWatcher(for fileURL: URL) {
        let descriptor = open(fileURL.path, O_EVTONLY)
        guard descriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .attrib, .delete, .rename],
            queue: queue
        )

        source.setEventHandler { [weak self, weak source] in
            self?.handleEvent(for: fileURL, flags: source?.data ?? [])
        }

        source.setCancelHandler { [weak self] in
            guard let self else { return }
            if let index = self.descriptors.firstIndex(of: descriptor) {
                self.descriptors.remove(at: index)
            }
            close(descriptor)
        }

        descriptors.append(descriptor)
        sources.append(source)
        source.resume()
    }

    private func handleEvent(for fileURL: URL, flags: DispatchSource.FileSystemEvent) {
        if flags.contains(.delete) || flags.contains(.rename) {
            start()
            return
        }

        let modified = modificationDate(for: fileURL)
        let previous = lastModifiedByPath[fileURL.path]
        if previous != modified {
            lastModifiedByPath[fileURL.path] = modified
            onChange()
        }
    }

    private func cacheModificationDate(for fileURL: URL) {
        lastModifiedByPath[fileURL.path] = modificationDate(for: fileURL)
    }

    private func modificationDate(for fileURL: URL) -> Date? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            return attributes[.modificationDate] as? Date
        } catch {
            return nil
        }
    }
}
