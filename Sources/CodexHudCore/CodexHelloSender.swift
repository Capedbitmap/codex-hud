import Foundation

public protocol HelloSending {
    func sendHello(modelName: String?, message: String) throws
}

public enum HelloSenderError: Error, Equatable {
    case codexNotFound
    case executionFailed
}

public struct CodexHelloSender: HelloSending {
    public init() {}

    public func sendHello(modelName: String?, message: String) throws {
        guard let codexPath = findCodexExecutable() else {
            throw HelloSenderError.codexNotFound
        }
        var arguments = ["exec", "--skip-git-repo-check"]
        if let modelName, !modelName.isEmpty {
            arguments.append(contentsOf: ["-m", modelName])
        }
        arguments.append(message)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: codexPath)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw HelloSenderError.executionFailed
        }
    }

    private func findCodexExecutable() -> String? {
        let env = ProcessInfo.processInfo.environment
        if let path = env["CODEX_BIN"], !path.isEmpty {
            return path
        }
        let which = Process()
        which.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        which.arguments = ["codex"]
        let pipe = Pipe()
        which.standardOutput = pipe
        try? which.run()
        which.waitUntilExit()
        guard which.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return output?.isEmpty == false ? output : nil
    }
}
