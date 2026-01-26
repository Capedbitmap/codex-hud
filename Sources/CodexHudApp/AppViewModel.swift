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
    private let weeklyReminderEvaluator = WeeklyResetReminderEvaluator()
    private let weeklyReminderPolicy = WeeklyResetReminderPolicy()
    private let helloSender: HelloSending
    private let refreshInterval: TimeInterval
    private var refreshTimer: Timer?
    private var stateTimer: Timer?
    private var authWatcher: AuthFileWatcher?
    private var logWatcher: SessionLogWatcher?
    private var stateWatcher: StateFileWatcher?
    private var lastAuthRefresh: Date?
    private var lastLogRefresh: Date?
    private var lastStateRefresh: Date?
    private var authChangeCutoff: Date?
    private var isRefreshing = false
    private var lastLogFileProcessed: URL?

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
        startStateMaintenance()
        startAuthWatcher()
        startLogWatcher()
        startStateWatcher()
    }

    var activeAccount: AccountRecord? {
        guard let activeEmail = state.activeEmail else { return nil }
        return state.accounts.first { $0.email == activeEmail }
    }

    var recommendation: RecommendationDecision {
        RecommendationEngine().recommend(accounts: state.accounts, activeEmail: state.activeEmail)
    }

    var priorityList: [AccountRecord] {
        RecommendationEngine().prioritize(accounts: state.accounts, activeEmail: state.activeEmail)
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

    var lastHelloSentAt: Date? {
        guard let activeEmail = state.activeEmail else { return nil }
        return state.dailyHelloRecords[activeEmail]?.lastRun
    }

    func refreshFromLogs() {
        guard !isRefreshing else { return }
        isRefreshing = true
        lastError = nil
        let authURL = defaultAuthURL()
        let logsURL = defaultLogsURL()

        Task {
            defer {
                if let activeEmail = state.activeEmail {
                    applyHelloAssumptionIfNeeded(for: activeEmail)
                }
                applyAssumedResets()
                evaluateWeeklyResetReminders()
                isRefreshing = false
            }
            do {
                let identity = try authDecoder.loadActiveAccount(from: authURL)
                updateActiveEmail(identity.email)
                guard let accountIndex = state.accounts.firstIndex(where: { $0.email == identity.email }) else {
                    lastError = "Active account is not configured in Settings."
                    persist()
                    return
                }
                let cutoff = authChangeCutoff
                let event = try await Task.detached(priority: .utility) {
                    let parser = SessionLogParser()
                    return try parser.latestTokenCountEvent(in: logsURL, since: cutoff)
                }.value

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
                authChangeCutoff = nil
                persist()
                evaluateNotifications(for: state.accounts[accountIndex])
            } catch let error as SessionLogError {
                switch error {
                case .noTokenCountEvents:
                    lastError = "No usage data yet for active account. Run /status once."
                case .logsNotFound:
                    lastError = "Codex logs not found."
                case .invalidPayload:
                    lastError = "Unable to parse usage logs."
                }
            } catch {
                lastError = "Unable to refresh from logs."
            }
        }
    }

    func requestNotifications() async -> NotificationAuthorizationRequestResult {
        await notificationManager.requestAuthorization()
    }

    func notificationStatusText() async -> String {
        let status = await notificationManager.currentAuthorizationStatus()
        switch status {
        case .unavailable(let reason):
            return reason.statusText
        case .available(let authorizationStatus):
            switch authorizationStatus {
            case .notDetermined:
                return "Not requested"
            case .denied:
                return "Denied"
            case .authorized:
                return "Enabled"
            case .provisional:
                return "Provisional"
            case .ephemeral:
                return "Ephemeral"
            @unknown default:
                return "Unknown"
            }
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
            updateActiveEmail(identity.email)
        } catch {
            return
        }
    }

    private func updateActiveEmail(_ email: String) {
        if state.activeEmail != email {
            state.activeEmail = email
            authChangeCutoff = authFileModifiedAt() ?? Date()
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

    private func startStateMaintenance() {
        stateTimer?.invalidate()
        stateTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.applyAssumedResets()
                self.evaluateWeeklyResetReminders()
            }
        }
        stateTimer?.tolerance = 6
    }

    private func startAuthWatcher() {
        authWatcher?.stop()
        authWatcher = AuthFileWatcher(authURL: defaultAuthURL()) { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.handleAuthChange()
            }
        }
        authWatcher?.start()
    }

    private func startLogWatcher() {
        logWatcher?.stop()
        logWatcher = SessionLogWatcher(logsURL: defaultLogsURL()) { [weak self] fileURL in
            guard let self else { return }
            Task { @MainActor in
                self.handleLogChange(fileURL)
            }
        }
        logWatcher?.start()
    }

    private func startStateWatcher() {
        stateWatcher?.stop()
        guard let storeURL = store?.fileURL else { return }
        stateWatcher = StateFileWatcher(fileURL: storeURL) { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.handleStateChange()
            }
        }
        stateWatcher?.start()
    }

    private func handleAuthChange() {
        let now = Date()
        if let last = lastAuthRefresh, now.timeIntervalSince(last) < 2 {
            return
        }
        lastAuthRefresh = now
        refreshFromLogs()
    }

    private func handleLogChange(_ fileURL: URL?) {
        let now = Date()
        if let last = lastLogRefresh, now.timeIntervalSince(last) < 5 {
            return
        }
        if let fileURL, fileURL == lastLogFileProcessed {
            return
        }
        lastLogRefresh = now
        lastLogFileProcessed = fileURL
        refreshFromLogs()
    }

    private func handleStateChange() {
        let now = Date()
        if let last = lastStateRefresh, now.timeIntervalSince(last) < 2 {
            return
        }
        lastStateRefresh = now
        guard let loaded = try? store?.load() else { return }
        if loaded.dailyHelloRecords != state.dailyHelloRecords {
            state.dailyHelloRecords = loaded.dailyHelloRecords
            evaluateHelloNotifications()
        }
        if loaded.weeklyReminderRecords != state.weeklyReminderRecords {
            state.weeklyReminderRecords = loaded.weeklyReminderRecords
        }
        if let activeEmail = state.activeEmail {
            applyHelloAssumptionIfNeeded(for: activeEmail)
        }
    }

    private func applyAssumedResets() {
        let now = Date()
        var didChange = false
        for index in state.accounts.indices {
            guard let snapshot = state.accounts[index].lastSnapshot else { continue }
            let updated = usageManager.applyAssumedResetsIfNeeded(snapshot: snapshot, now: now)
            if updated != snapshot {
                state.accounts[index].lastSnapshot = updated
                didChange = true
            }
        }
        if didChange {
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

    private func evaluateWeeklyResetReminder(for account: AccountRecord) {
        guard let weekly = account.lastSnapshot?.weekly else { return }
        guard account.email != state.activeEmail else { return }
        let record = state.weeklyReminderRecords[account.email]
        let decision = weeklyReminderEvaluator.decision(
            now: Date(),
            weekly: weekly,
            record: record,
            policy: weeklyReminderPolicy
        )
        guard case let .allowed(nextRecord) = decision else { return }
        state.weeklyReminderRecords[account.email] = nextRecord
        persist()
        notificationManager.sendWeeklyResetReminder(WeeklyResetReminderEvent(
            accountEmail: account.email,
            codexNumber: account.codexNumber,
            resetsAt: weekly.resetsAt
        ))
    }

    private func evaluateWeeklyResetReminders() {
        for account in state.accounts where account.email != state.activeEmail {
            evaluateWeeklyResetReminder(for: account)
        }
    }

    private func evaluateHelloNotifications() {
        guard let activeEmail = state.activeEmail,
              let lastRun = state.dailyHelloRecords[activeEmail]?.lastRun,
              let account = state.accounts.first(where: { $0.email == activeEmail }) else { return }
        if let lastNotified = state.helloNotificationRecords[activeEmail],
           lastNotified >= lastRun {
            return
        }
        state.helloNotificationRecords[activeEmail] = lastRun
        persist()
        notificationManager.sendHelloSentNotification(
            accountEmail: account.email,
            codexNumber: account.codexNumber,
            sentAt: lastRun
        )
    }

    private func applyHelloAssumptionIfNeeded(for email: String) {
        guard let record = state.dailyHelloRecords[email],
              let lastRun = record.lastRun,
              let index = state.accounts.firstIndex(where: { $0.email == email }),
              let snapshot = state.accounts[index].lastSnapshot else { return }
        if snapshot.capturedAt >= lastRun {
            return
        }
        let windowMinutes = snapshot.fiveHour.windowMinutes > 0 ? snapshot.fiveHour.windowMinutes : 300
        let assumedReset = lastRun.addingTimeInterval(TimeInterval(windowMinutes * 60))
        if snapshot.fiveHour.assumedReset && snapshot.fiveHour.resetsAt == assumedReset {
            return
        }
        let updatedFiveHour = UsageWindow(
            kind: .fiveHour,
            usedPercent: 0,
            windowMinutes: windowMinutes,
            resetsAt: assumedReset,
            isStale: snapshot.fiveHour.isStale,
            assumedReset: true
        )
        let updatedSnapshot = RateLimitsSnapshot(
            capturedAt: lastRun,
            fiveHour: updatedFiveHour,
            weekly: snapshot.weekly,
            source: snapshot.source
        )
        state.accounts[index].lastSnapshot = updatedSnapshot
        state.accounts[index].lastUpdated = Date()
        persist()
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
            try helloSender.sendHello(modelName: defaultHelloModel(), message: "hi")
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
        return "gpt-5.1-codex-mini"
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

    private func authFileModifiedAt() -> Date? {
        let url = defaultAuthURL()
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.modificationDate] as? Date
        } catch {
            return nil
        }
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
