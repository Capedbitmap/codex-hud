import Foundation

final class StateFileWatcher {
    private let fileURL: URL
    private let queue: DispatchQueue
    private let onChange: () -> Void
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var lastModified: Date?

    init(fileURL: URL, onChange: @escaping () -> Void) {
        self.fileURL = fileURL
        self.queue = DispatchQueue(label: "codex.hud.statewatcher")
        self.onChange = onChange
    }

    func start() {
        stop()
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        fileDescriptor = open(fileURL.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: queue
        )

        source?.setEventHandler { [weak self] in
            self?.handleEvent()
        }

        source?.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                close(fd)
            }
            self?.fileDescriptor = -1
        }

        source?.resume()
        checkForChange()
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    private func handleEvent() {
        let flags = source?.data ?? []
        if flags.contains(.delete) || flags.contains(.rename) {
            start()
            return
        }
        checkForChange()
    }

    private func checkForChange() {
        guard let date = modificationDate() else { return }
        if let last = lastModified, last == date { return }
        lastModified = date
        onChange()
    }

    private func modificationDate() -> Date? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            return attributes[.modificationDate] as? Date
        } catch {
            return nil
        }
    }
}
