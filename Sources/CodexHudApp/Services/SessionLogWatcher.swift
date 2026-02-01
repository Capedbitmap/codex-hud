import Foundation

final class SessionLogWatcher {
    private let logsURL: URL
    private let queue: DispatchQueue
    private let onChange: (URL?) -> Void
    private let locator: SessionLogLocator
    private var rootSource: DispatchSourceFileSystemObject?
    private var rootDescriptor: Int32 = -1
    private var sessionSource: DispatchSourceFileSystemObject?
    private var sessionDescriptor: Int32 = -1
    private var fileSource: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var currentFile: URL?
    private var currentSessionDir: URL?

    init(logsURL: URL, onChange: @escaping (URL?) -> Void) {
        self.logsURL = logsURL
        self.queue = DispatchQueue(label: "codex.hud.logwatcher")
        self.onChange = onChange
        self.locator = SessionLogLocator(logsURL: logsURL)
    }

    func start() {
        stop()
        guard FileManager.default.fileExists(atPath: logsURL.path) else { return }
        startRootWatcher()
        updateFileWatcher()
    }

    func stop() {
        rootSource?.cancel()
        sessionSource?.cancel()
        fileSource?.cancel()
        rootSource = nil
        sessionSource = nil
        fileSource = nil
    }

    private func startRootWatcher() {
        rootDescriptor = open(logsURL.path, O_EVTONLY)
        guard rootDescriptor >= 0 else { return }
        rootSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: rootDescriptor,
            eventMask: [.write, .rename, .delete],
            queue: queue
        )
        rootSource?.setEventHandler { [weak self] in
            self?.updateFileWatcher()
        }
        rootSource?.setCancelHandler { [weak self] in
            if let fd = self?.rootDescriptor, fd >= 0 { close(fd) }
            self?.rootDescriptor = -1
        }
        rootSource?.resume()
    }

    private func startSessionWatcher(for directory: URL) {
        sessionDescriptor = open(directory.path, O_EVTONLY)
        guard sessionDescriptor >= 0 else { return }
        sessionSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: sessionDescriptor,
            eventMask: [.write, .rename, .delete],
            queue: queue
        )
        sessionSource?.setEventHandler { [weak self] in
            self?.updateFileWatcher()
        }
        sessionSource?.setCancelHandler { [weak self] in
            if let fd = self?.sessionDescriptor, fd >= 0 { close(fd) }
            self?.sessionDescriptor = -1
        }
        sessionSource?.resume()
    }

    private func startFileWatcher(for file: URL) {
        fileDescriptor = open(file.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }
        fileSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend, .attrib, .rename, .delete],
            queue: queue
        )
        fileSource?.setEventHandler { [weak self] in
            guard let self else { return }
            let flags = self.fileSource?.data ?? []
            if flags.contains(.delete) || flags.contains(.rename) {
                self.updateFileWatcher()
                return
            }
            self.onChange(self.currentFile)
        }
        fileSource?.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 { close(fd) }
            self?.fileDescriptor = -1
        }
        fileSource?.resume()
    }

    private func updateFileWatcher() {
        guard let latest = locator.latestLogFile() else { return }
        if currentFile != latest {
            fileSource?.cancel()
            fileSource = nil
            currentFile = latest
            startFileWatcher(for: latest)
        }
        let sessionDir = latest.deletingLastPathComponent()
        if currentSessionDir != sessionDir {
            sessionSource?.cancel()
            sessionSource = nil
            currentSessionDir = sessionDir
            startSessionWatcher(for: sessionDir)
        }
    }
}
