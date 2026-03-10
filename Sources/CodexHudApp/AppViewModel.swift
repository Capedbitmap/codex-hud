import Foundation
import CodexHudCore

@MainActor
final class AppViewModel: ObservableObject {
    @Published private(set) var state: AppState
    @Published private(set) var lastError: String?
    @Published private(set) var lastRefreshSource: SnapshotSource?

    private let store: AppStateStore?
    private let authURL: URL
    private let logsURL: URL
    private let threadDatabaseURL: URL
    private let authDecoder = AuthDecoder()
    private let threadStore: ThreadActivityStore
    private let refreshPlanner = SessionRefreshPlanner()
    private let usageManager = UsageStateManager()
    private let notificationEvaluator = NotificationEvaluator()
    private let notificationManager = NotificationManager()
    private let forcedRefreshEvaluator = ForcedRefreshEvaluator()
    private let weeklyReminderEvaluator = WeeklyResetReminderEvaluator()
    private let weeklyReminderPolicy = WeeklyResetReminderPolicy()
    private let helloSender: HelloSending
    private let logIngestor: SessionLogIngestor
    private let healthCheckInterval: TimeInterval
    private var healthTimer: Timer?
    private var maintenanceTimer: Timer?
    private var authWatcher: AuthFileWatcher?
    private var threadActivityWatcher: ThreadActivityWatcher?
    private var logWatcher: SessionLogWatcher?
    private var stateWatcher: StateFileWatcher?
    private var lastAuthRefresh: Date?
    private var lastThreadActivityRefresh: Date?
    private var lastLogRefresh: Date?
    private var lastStateRefresh: Date?
    private var isRefreshing = false
    private var pendingForceRefresh = false

    init(
        helloSender: HelloSending = CodexHelloSender(),
        healthCheckInterval: TimeInterval = AppViewModel.defaultHealthCheckInterval,
        store: AppStateStore? = nil,
        authURL: URL? = nil,
        logsURL: URL? = nil,
        threadDatabaseURL: URL? = nil,
        startObservers: Bool = true
    ) {
        self.helloSender = helloSender
        self.healthCheckInterval = healthCheckInterval
        self.authURL = authURL ?? URL(fileURLWithPath: "~/.codex/auth.json").expandingTildeInPath
        self.logsURL = logsURL ?? URL(fileURLWithPath: "~/.codex/sessions").expandingTildeInPath
        self.threadDatabaseURL = threadDatabaseURL ?? URL(fileURLWithPath: "~/.codex/state_5.sqlite").expandingTildeInPath
        self.threadStore = ThreadActivityStore(databaseURL: self.threadDatabaseURL)
        self.logIngestor = SessionLogIngestor(logsURL: self.logsURL, tailBytes: Self.logTailBytes)
        if let store {
            self.store = store
        } else {
            do {
                self.store = try AppStateStore.defaultStore()
            } catch {
                self.store = nil
            }
        }
        if let stored = try? self.store?.load() {
            state = stored
        } else {
            state = AppState(accounts: [], activeEmail: nil, lastRefresh: nil)
        }
        migrateCodexAccountNumbersIfNeeded()
        refreshActiveEmail()
        applyAssumedResets()
        if startObservers {
            startHealthChecks()
            startMaintenance()
            startAuthWatcher()
            startThreadActivityWatcher()
            startLogWatcher()
            startStateWatcher()
        }
        refreshFromLogs()
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

    func manualRefresh() {
        Task { @MainActor in
            self.refreshFromLogs(force: true)
            try? await Task.sleep(nanoseconds: 750_000_000)
            guard self.shouldAttemptForcedRefreshAfterScan else { return }
            guard let activeEmail = self.state.activeEmail else { return }
            self.attemptForcedRefresh(for: activeEmail, hasAuth: self.currentIdentity() != nil)
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            self.refreshFromLogs(force: true)
        }
    }

    func refreshFromLogs(force: Bool = false) {
        if isRefreshing {
            pendingForceRefresh = pendingForceRefresh || force
            return
        }
        isRefreshing = true
        lastError = nil

        Task {
            defer {
                if let activeEmail = state.activeEmail {
                    applyHelloAssumptionIfNeeded(for: activeEmail)
                }
                applyAssumedResets()
                evaluateWeeklyResetReminders()
                isRefreshing = false
                if pendingForceRefresh {
                    pendingForceRefresh = false
                    refreshFromLogs(force: true)
                }
            }
            do {
                let observedAt = authFileModifiedAt() ?? Date()
                let identity = currentIdentity()
                if let identity {
                    recordAuthObservation(identity, observedAt: observedAt)
                }
                let refreshAt = Date()
                let changes = try await refreshSnapshots(force: force, currentIdentity: identity, observedAt: observedAt, refreshAt: refreshAt)
                guard let activeEmail = state.activeEmail,
                      let activeAccount = state.accounts.first(where: { $0.email == activeEmail }) else {
                    lastError = identity == nil
                        ? "No active Codex session could be mapped yet."
                        : "Active account is not configured in Settings."
                    persist()
                    return
                }
                guard let activeSnapshot = activeAccount.lastSnapshot else {
                    lastError = "No usage data yet for active session. Run /status once."
                    persist()
                    return
                }
                if changes == 0, force || activeSnapshot.source == .sessionLog {
                    state.lastRefresh = refreshAt
                    lastRefreshSource = .sessionLog
                }
                persist()
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

    func sendTestNotification() {
        notificationManager.sendTestNotification()
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
        state.sessionBindings = pruneSessionBindings(state.sessionBindings, configuredEmails: Set(state.accounts.map(\.email)))
        persist()
    }

    func storagePath() -> String? {
        store?.fileURL.path
    }

    private func refreshActiveEmail() {
        do {
            let identity = try authDecoder.loadActiveAccount(from: authURL)
            recordAuthObservation(identity, observedAt: authFileModifiedAt() ?? Date())
            if state.activeEmail == nil, state.accounts.contains(where: { $0.email == identity.email }) {
                updateActiveEmail(identity.email)
            }
        } catch {
            return
        }
    }

    private func updateActiveEmail(_ email: String) {
        if state.activeEmail != email {
            state.activeEmail = email
        }
    }

    private func startHealthChecks() {
        healthTimer?.invalidate()
        healthTimer = Timer.scheduledTimer(withTimeInterval: healthCheckInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.refreshFromLogs()
            }
        }
        healthTimer?.tolerance = max(60, healthCheckInterval * 0.2)
    }

    private func startMaintenance() {
        maintenanceTimer?.invalidate()
        maintenanceTimer = Timer.scheduledTimer(withTimeInterval: 60 * 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.applyAssumedResets()
                self.evaluateWeeklyResetReminders()
            }
        }
        maintenanceTimer?.tolerance = 10 * 60
    }

    private func startAuthWatcher() {
        authWatcher?.stop()
        authWatcher = AuthFileWatcher(authURL: authURL) { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.handleAuthChange()
            }
        }
        authWatcher?.start()
    }

    private func startThreadActivityWatcher() {
        threadActivityWatcher?.stop()
        threadActivityWatcher = ThreadActivityWatcher(fileURLs: threadActivityFiles()) { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.handleThreadActivityChange()
            }
        }
        threadActivityWatcher?.start()
    }

    private func startLogWatcher() {
        logWatcher?.stop()
        logWatcher = SessionLogWatcher(logsURL: logsURL) { [weak self] fileURL in
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
        refreshFromLogs(force: true)
    }

    private func handleThreadActivityChange() {
        let now = Date()
        if let last = lastThreadActivityRefresh, now.timeIntervalSince(last) < 0.5 {
            return
        }
        lastThreadActivityRefresh = now
        refreshFromLogs()
    }

    private func handleLogChange(_ fileURL: URL?) {
        let now = Date()
        if let last = lastLogRefresh, now.timeIntervalSince(last) < 1 {
            return
        }
        lastLogRefresh = now
        if fileURL == nil {
            refreshFromLogs()
            return
        }
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

    private func refreshSnapshots(
        force: Bool,
        currentIdentity: AuthAccountIdentity?,
        observedAt: Date,
        refreshAt: Date
    ) async throws -> Int {
        let originalBindings = state.sessionBindings
        let originalObservations = state.authObservations
        let recentThreads = try threadStore.recentThreads(limit: Self.maxRecentThreads)
        let configuredEmails = Set(state.accounts.map(\.email))
        let metadataByRolloutPath = try await sessionMetadataByRolloutPath(recentThreads: recentThreads)
        let plan = refreshPlanner.plan(
            state: state,
            configuredEmails: configuredEmails,
            recentThreads: recentThreads,
            metadataByRolloutPath: metadataByRolloutPath,
            currentIdentity: currentIdentity,
            observedAt: observedAt,
            now: refreshAt
        )
        var bindings = plan.bindings
        var latestByEmail: [String: (binding: SessionAccountBinding, event: TokenCountEvent)] = [:]
        var latestActivityByEmail: [String: Date] = [:]
        state.sessionBindings = bindings
        pruneAuthObservations()

        for thread in recentThreads {
            guard let binding = bindings[thread.sessionID],
                  configuredEmails.contains(binding.email) else {
                continue
            }
            let current = latestActivityByEmail[binding.email] ?? .distantPast
            if thread.updatedAt > current {
                latestActivityByEmail[binding.email] = thread.updatedAt
            }
        }

        for binding in bindings.values where configuredEmails.contains(binding.email) {
            let fileURL = URL(fileURLWithPath: binding.rolloutPath)
            let cutoff = force ? nil : state.accounts.first(where: { $0.email == binding.email })?.lastSnapshot?.capturedAt
            guard let event = try await logIngestor.latestTokenCountEvent(in: fileURL, since: cutoff) else { continue }
            var refreshedBinding = binding
            refreshedBinding.lastObservedAt = max(binding.lastObservedAt, event.timestamp)
            bindings[binding.sessionID] = refreshedBinding
            if let current = latestByEmail[binding.email] {
                if event.timestamp > current.event.timestamp {
                    latestByEmail[binding.email] = (refreshedBinding, event)
                }
            } else {
                latestByEmail[binding.email] = (refreshedBinding, event)
            }
        }

        state.sessionBindings = bindings
        if let activeEmail = plan.activeEmail {
            updateActiveEmail(activeEmail)
        } else {
            state.activeEmail = nil
        }

        var changeCount = 0
        var updatedAccounts: [AccountRecord] = []

        for index in state.accounts.indices {
            let email = state.accounts[index].email
            let snapshotCandidate: RateLimitsSnapshot?
            if let candidate = latestByEmail[email],
               let parsed = snapshot(for: candidate.event) {
                snapshotCandidate = parsed
            } else if let existing = state.accounts[index].lastSnapshot,
                      let latestActivityAt = latestActivityByEmail[email] {
                snapshotCandidate = inferredSnapshot(from: existing, latestActivityAt: latestActivityAt)
            } else {
                snapshotCandidate = nil
            }

            guard let snapshot = snapshotCandidate else {
                continue
            }

            let hasMeaningfulChange = state.accounts[index].lastSnapshot != snapshot
            guard hasMeaningfulChange || force else { continue }

            state.accounts[index].lastSnapshot = snapshot
            if hasMeaningfulChange {
                state.accounts[index].lastUpdated = refreshAt
                updatedAccounts.append(state.accounts[index])
                changeCount += 1
            }
            state.lastRefresh = refreshAt
            lastRefreshSource = snapshot.source
        }

        let attributionChanged = state.sessionBindings != originalBindings || state.authObservations != originalObservations
        if changeCount > 0 || attributionChanged {
            persist()
        }

        if changeCount > 0 {
            for account in updatedAccounts {
                evaluateNotifications(for: account)
            }
        }

        return changeCount
    }

    private func snapshot(for event: TokenCountEvent) -> RateLimitsSnapshot? {
        guard let primary = event.primary, let secondary = event.secondary else {
            return nil
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
        return RateLimitsSnapshot(capturedAt: event.timestamp, fiveHour: fiveHour, weekly: weekly, source: .sessionLog)
    }

    private func inferredSnapshot(from existing: RateLimitsSnapshot, latestActivityAt: Date) -> RateLimitsSnapshot {
        var fiveHour = existing.fiveHour
        var weekly = existing.weekly
        var capturedAt = existing.capturedAt
        var changed = false

        let shouldReanchorFiveHour = latestActivityAt > existing.capturedAt
            && (existing.fiveHour.assumedReset || latestActivityAt > existing.fiveHour.resetsAt)
        if shouldReanchorFiveHour {
            let windowMinutes = max(existing.fiveHour.windowMinutes, 300)
            fiveHour = UsageWindow(
                kind: .fiveHour,
                usedPercent: 0,
                windowMinutes: windowMinutes,
                resetsAt: latestActivityAt.addingTimeInterval(TimeInterval(windowMinutes * 60)),
                isStale: true,
                assumedReset: true
            )
            capturedAt = max(capturedAt, latestActivityAt)
            changed = true
        }

        if latestActivityAt > existing.weekly.resetsAt {
            let windowMinutes = max(existing.weekly.windowMinutes, 7 * 24 * 60)
            weekly = UsageWindow(
                kind: .weekly,
                usedPercent: 0,
                windowMinutes: windowMinutes,
                resetsAt: latestActivityAt.addingTimeInterval(TimeInterval(windowMinutes * 60)),
                isStale: true,
                assumedReset: true
            )
            capturedAt = max(capturedAt, latestActivityAt)
            changed = true
        }

        guard changed else { return existing }
        return RateLimitsSnapshot(
            capturedAt: capturedAt,
            fiveHour: fiveHour,
            weekly: weekly,
            source: existing.source
        )
    }

    private func recordAuthObservation(_ identity: AuthAccountIdentity, observedAt: Date) {
        if let last = state.authObservations.last,
           last.email == identity.email,
           last.subject == identity.subject,
           last.accountId == identity.accountId,
           abs(last.observedAt.timeIntervalSince(observedAt)) < 1 {
            return
        }

        state.authObservations.append(AuthObservation(
            email: identity.email,
            subject: identity.subject,
            accountId: identity.accountId,
            observedAt: observedAt
        ))
        pruneAuthObservations()
    }

    private func pruneAuthObservations() {
        state.authObservations = Array(state.authObservations.suffix(Self.maxAuthObservations))
    }

    private func pruneSessionBindings(
        _ bindings: [String: SessionAccountBinding],
        configuredEmails: Set<String>
    ) -> [String: SessionAccountBinding] {
        let cutoff = Date().addingTimeInterval(-Self.sessionBindingRetention)
        return bindings.filter { _, binding in
            configuredEmails.contains(binding.email)
                && binding.lastObservedAt >= cutoff
                && FileManager.default.fileExists(atPath: binding.rolloutPath)
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

    private func migrateCodexAccountNumbersIfNeeded() {
        let numbers = state.accounts.map(\.codexNumber).sorted()
        let expected = Array(2...(numbers.count + 1))
        guard !numbers.isEmpty, numbers == expected else { return }
        state.accounts = state.accounts.map { account in
            var updated = account
            updated.codexNumber -= 1
            return updated
        }.sorted { $0.codexNumber < $1.codexNumber }
        persist()
    }

    private func authFileModifiedAt() -> Date? {
        let url = authURL
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.modificationDate] as? Date
        } catch {
            return nil
        }
    }

    private func currentIdentity() -> AuthAccountIdentity? {
        try? authDecoder.loadActiveAccount(from: authURL)
    }

    private var shouldAttemptForcedRefreshAfterScan: Bool {
        guard let activeEmail = state.activeEmail,
              let account = state.accounts.first(where: { $0.email == activeEmail }),
              let snapshot = account.lastSnapshot else {
            return false
        }
        return snapshot.fiveHour.assumedReset || snapshot.weekly.assumedReset
    }

    private func threadActivityFiles() -> [URL] {
        let walURL = URL(fileURLWithPath: threadDatabaseURL.path + "-wal")
        return [threadDatabaseURL, walURL, threadDatabaseURL.deletingLastPathComponent()]
    }

    private func sessionMetadataByRolloutPath(
        recentThreads: [CodexThreadActivity]
    ) async throws -> [String: SessionMetadata] {
        var metadataByRolloutPath: [String: SessionMetadata] = [:]

        for thread in recentThreads {
            let fileURL = URL(fileURLWithPath: thread.rolloutPath)
            guard let metadata = try await logIngestor.sessionMetadata(in: fileURL) else { continue }
            metadataByRolloutPath[thread.rolloutPath] = metadata
        }

        return metadataByRolloutPath
    }

}

private extension URL {
    var expandingTildeInPath: URL {
        let path = (self.path as NSString).expandingTildeInPath
        return URL(fileURLWithPath: path)
    }
}

private extension AppViewModel {
    // Safety net in case filesystem events are missed (sleep/wake, log rotation, etc.).
    // Parsing is tail-based so this is intentionally kept reasonably frequent.
    static let defaultHealthCheckInterval: TimeInterval = 5 * 60
    static let logTailBytes: Int = 256 * 1024
    static let maxRecentThreads: Int = 96
    static let maxAuthObservations: Int = 64
    static let sessionBindingRetention: TimeInterval = 45 * 24 * 60 * 60
}
