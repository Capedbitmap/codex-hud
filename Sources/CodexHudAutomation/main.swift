import Foundation
import CodexHudCore

struct AutomationRunner {
    private let authDecoder = AuthDecoder()
    private let forcedRefreshEvaluator = ForcedRefreshEvaluator()
    private let dailyHelloEvaluator = DailyHelloEvaluator()
    private let dailyHelloPolicy = DailyHelloPolicy()
    private let helloSender: HelloSending
    private let store: AppStateStore

    init() throws {
        self.helloSender = CodexHelloSender()
        self.store = try AppStateStore.defaultStore()
    }

    func runDailyHello() throws {
        let now = Date()
        guard let state = try store.load() else { return }
        let identity = try authDecoder.loadActiveAccount(from: defaultAuthURL())
        guard let account = state.accounts.first(where: { $0.email == identity.email }) else { return }

        if let remaining = weeklyRemainingPercent(account) {
            if remaining <= UsageThresholds.default.depleted {
                return
            }
        }

        let record = state.dailyHelloRecords[identity.email]
        let started = fiveHourStarted(account: account, now: now, startHour: dailyHelloPolicy.startHour)
        let decision = dailyHelloEvaluator.decision(
            now: now,
            record: record,
            policy: dailyHelloPolicy,
            fiveHourStarted: started
        )
        guard case let .allowed(updatedRecord) = decision else { return }

        var updated = state
        updated.dailyHelloRecords[identity.email] = updatedRecord
        try store.save(updated)
        try helloSender.sendHello(modelName: defaultHelloModel(), message: "hi")
    }

    func runForcedRefreshIfNeeded() throws {
        let now = Date()
        guard let state = try store.load() else { return }
        let identity = try authDecoder.loadActiveAccount(from: defaultAuthURL())
        let record = state.forcedRefreshRecords[identity.email]
        let remaining = state.accounts.first(where: { $0.email == identity.email }).flatMap(weeklyRemainingPercent)
        let decision = forcedRefreshEvaluator.decision(now: now, weeklyRemaining: remaining, record: record, hasAuth: true)
        guard decision.allowed else { return }

        var updated = state
        updated.forcedRefreshRecords[identity.email] = ForcedRefreshRecord(lastAttempt: now, lastSuccess: record?.lastSuccess, lastFailure: record?.lastFailure)
        try store.save(updated)

        do {
            try helloSender.sendHello(modelName: defaultHelloModel(), message: "hi")
            updated.forcedRefreshRecords[identity.email]?.lastSuccess = Date()
            try store.save(updated)
        } catch {
            updated.forcedRefreshRecords[identity.email]?.lastFailure = Date()
            try store.save(updated)
            throw error
        }
    }

    private func weeklyRemainingPercent(_ account: AccountRecord) -> Percent? {
        guard let used = Percent(rawValue: account.lastSnapshot?.weekly.usedPercent ?? 0) else { return nil }
        return Percent(rawValue: 100 - used.value)
    }

    private func fiveHourStarted(account: AccountRecord, now: Date, startHour: Int) -> Bool {
        guard let snapshot = account.lastSnapshot else { return false }
        let calendar = Calendar.current
        guard let windowStart = calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: now) else {
            return false
        }
        guard snapshot.capturedAt >= windowStart else { return false }
        return snapshot.fiveHour.usedPercent > 0
    }

    private func defaultAuthURL() -> URL {
        URL(fileURLWithPath: "~/.codex/auth.json").expandingTildeInPath
    }

    private func defaultHelloModel() -> String? {
        if let override = ProcessInfo.processInfo.environment["CODEX_HUD_HELLO_MODEL"], !override.isEmpty {
            return override
        }
        return "gpt-5.1-codex-mini"
    }
}

let args = Set(CommandLine.arguments)

do {
    let runner = try AutomationRunner()
    if args.contains("--daily-hello") {
        try runner.runDailyHello()
    } else if args.contains("--forced-refresh") {
        try runner.runForcedRefreshIfNeeded()
    } else {
        try runner.runDailyHello()
    }
} catch {
    FileHandle.standardError.write(Data("Automation failed.\n".utf8))
    exit(1)
}

private extension URL {
    var expandingTildeInPath: URL {
        let path = (self.path as NSString).expandingTildeInPath
        return URL(fileURLWithPath: path)
    }
}
