import Foundation

final class SessionLogWatcher {
    private let logsURL: URL
    private let queue: DispatchQueue
    private let onChange: () -> Void
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1

    init(logsURL: URL, onChange: @escaping () -> Void) {
        self.logsURL = logsURL
        self.queue = DispatchQueue(label: "codex.hud.logwatcher")
        self.onChange = onChange
    }

    func start() {
        stop()
        guard FileManager.default.fileExists(atPath: logsURL.path) else { return }
        fileDescriptor = open(logsURL.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend, .attrib, .rename, .delete],
            queue: queue
        )

        source?.setEventHandler { [weak self] in
            self?.onChange()
        }

        source?.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                close(fd)
            }
            self?.fileDescriptor = -1
        }

        source?.resume()
    }

    func stop() {
        source?.cancel()
        source = nil
    }
}
