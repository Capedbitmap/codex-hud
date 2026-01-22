import Foundation
import CodexHudCore

@MainActor
final class AppViewModel: ObservableObject {
    @Published private(set) var state: AppState
    @Published private(set) var lastError: String?
    @Published private(set) var lastRefreshSource: SnapshotSource?

    private let store: AppStateStore?
    private let logParser = SessionLogParser()
    private let authDecoder = AuthDecoder()
    private let usageManager = UsageStateManager()
    private let notificationEvaluator = NotificationEvaluator()
    private let notificationManager = NotificationManager()
    private let forcedRefreshEvaluator = ForcedRefreshEvaluator()
    private let helloSender: HelloSending
    private let refreshInterval: TimeInterval
    private var refreshTimer: Timer?

    init(
        helloSender: HelloSending = CodexHelloSender(),
        refreshInterval: TimeInterval = AppViewModel.defaultRefreshInterval
    ) {
        self.helloSender = helloSender
        self.refreshInterval = refreshInterval
        do {
            store = try AppStateStore.defaultStore()
        } catch {
            store = nil
        }
        if let stored = try? store?.load() {
            state = stored
        } else {
            state = AppState(accounts: [], activeEmail: nil, lastRefresh: nil)
        }
        refreshActiveEmail()
        applyAssumedResets()
        startAutoRefresh()
    }

    var activeAccount: AccountRecord? {
        guard let activeEmail = state.activeEmail else { return nil }
        return state.accounts.first { $0.email == activeEmail }
    }

    var recommendation: RecommendationDecision {
        RecommendationEngine().recommend(accounts: state.accounts, activeEmail: state.activeEmail)
    }

    var weeklyRemainingPercent: Percent? {
        guard let weeklyUsed = activeAccount?.lastSnapshot?.weekly.usedPercent,
              let used = Percent(rawValue: weeklyUsed) else { return nil }
        return Percent(rawValue: 100 - used.value)
    }

    var shouldShowFiveHour: Bool {
        guard let remaining = weeklyRemainingPercent else { return false }
        return remaining > UsageThresholds.default.depleted
    }

    func refreshFromLogs() {
        lastError = nil
        do {
            let identity = try authDecoder.loadActiveAccount(from: defaultAuthURL())
            state.activeEmail = identity.email
            guard let accountIndex = state.accounts.firstIndex(where: { $0.email == identity.email }) else {
                lastError = "Active account is not configured in Settings."
                persist()
                return
            }
            let event = try logParser.latestTokenCountEvent(in: defaultLogsURL())
            guard let primary = event.primary, let secondary = event.secondary else {
                lastError = "Usage data missing in logs."
                attemptForcedRefresh(for: identity.email, hasAuth: true)
                persist()
                return
            }
            let fiveHour = UsageWindow(
                kind: .fiveHour,
                usedPercent: primary.usedPercent,
                windowMinutes: primary.windowMinutes,
                resetsAt: primary.resetsAt,
                isStale: false,
                assumedReset: false
            )
            let weekly = UsageWindow(
                kind: .weekly,
                usedPercent: secondary.usedPercent,
                windowMinutes: secondary.windowMinutes,
                resetsAt: secondary.resetsAt,
                isStale: false,
                assumedReset: false
            )
            let snapshot = RateLimitsSnapshot(capturedAt: event.timestamp, fiveHour: fiveHour, weekly: weekly, source: .sessionLog)
            state.accounts[accountIndex].lastSnapshot = snapshot
            state.accounts[accountIndex].lastUpdated = Date()
            state.lastRefresh = Date()
            lastRefreshSource = snapshot.source
            persist()
            evaluateNotifications(for: state.accounts[accountIndex])
        } catch {
            lastError = "Unable to refresh from logs."
        }
    }

    func saveAccounts(_ accounts: [AccountRecord]) {
        let normalized = accounts.map { incoming -> AccountRecord in
            if let existing = state.accounts.first(where: { $0.email == incoming.email }) {
                return AccountRecord(
                    codexNumber: incoming.codexNumber,
                    email: incoming.email,
                    displayName: incoming.displayName,
                    lastSnapshot: existing.lastSnapshot,
                    lastUpdated: existing.lastUpdated
                )
            }
            return incoming
        }
        state.accounts = normalized.sorted { $0.codexNumber < $1.codexNumber }
        if let activeEmail = state.activeEmail, !state.accounts.contains(where: { $0.email == activeEmail }) {
            state.activeEmail = nil
        }
        persist()
    }

    func storagePath() -> String? {
        store?.fileURL.path
    }

    private func refreshActiveEmail() {
        do {
            let identity = try authDecoder.loadActiveAccount(from: defaultAuthURL())
            state.activeEmail = identity.email
        } catch {
            return
        }
    }

    private func startAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.refreshFromLogs()
            }
        }
        refreshTimer?.tolerance = refreshInterval * 0.1
        refreshFromLogs()
    }

    private func applyAssumedResets() {
        guard let activeIndex = state.activeEmail.flatMap({ email in
            state.accounts.firstIndex(where: { $0.email == email })
        }) else { return }
        guard let snapshot = state.accounts[activeIndex].lastSnapshot else { return }
        let updated = usageManager.applyAssumedResetsIfNeeded(snapshot: snapshot, now: Date())
        if updated != snapshot {
            state.accounts[activeIndex].lastSnapshot = updated
            persist()
        }
    }

    private func evaluateNotifications(for account: AccountRecord) {
        let previous = state.notificationLedger[account.email]
        guard let evaluation = notificationEvaluator.evaluate(account: account, previous: previous) else { return }
        state.notificationLedger[account.email] = evaluation.snapshot
        persist()
        notificationManager.send(events: evaluation.events, recommendation: recommendation)
    }

    private func attemptForcedRefresh(for email: String, hasAuth: Bool) {
        let record = state.forcedRefreshRecords[email]
        let decision = forcedRefreshEvaluator.decision(
            now: Date(),
            weeklyRemaining: weeklyRemainingPercent,
            record: record,
            hasAuth: hasAuth
        )
        guard decision.allowed else { return }
        state.forcedRefreshRecords[email] = ForcedRefreshRecord(lastAttempt: Date(), lastSuccess: record?.lastSuccess, lastFailure: record?.lastFailure)
        persist()
        do {
            try helloSender.sendHello(modelName: defaultHelloModel())
            state.forcedRefreshRecords[email]?.lastSuccess = Date()
            lastRefreshSource = .forcedRefresh
            persist()
        } catch {
            state.forcedRefreshRecords[email]?.lastFailure = Date()
            lastError = "Forced refresh failed."
            persist()
        }
    }

    private func defaultHelloModel() -> String? {
        if let override = ProcessInfo.processInfo.environment["CODEX_HUD_HELLO_MODEL"], !override.isEmpty {
            return override
        }
        return "gpt-5.2-codex-mini"
    }

    private func persist() {
        guard let store else { return }
        do {
            try store.save(state)
        } catch {
            lastError = "Unable to persist data."
        }
    }

    private func defaultLogsURL() -> URL {
        URL(fileURLWithPath: "~/.codex/sessions").expandingTildeInPath
    }

    private func defaultAuthURL() -> URL {
        URL(fileURLWithPath: "~/.codex/auth.json").expandingTildeInPath
    }

}

private extension URL {
    var expandingTildeInPath: URL {
        let path = (self.path as NSString).expandingTildeInPath
        return URL(fileURLWithPath: path)
    }
}

private extension AppViewModel {
    static let defaultRefreshInterval: TimeInterval = 300
}
