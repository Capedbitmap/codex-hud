import Foundation
import CodexHudCore

@MainActor
final class AppViewModel: ObservableObject {
    @Published private(set) var state: AppState
    @Published private(set) var lastError: String?
    @Published private(set) var lastRefreshSource: SnapshotSource?

    private let store: AppStateStore?
    private let authDecoder = AuthDecoder()
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
    private var sessionIndexWatcher: SessionIndexWatcher?
    private var logWatcher: SessionLogWatcher?
    private var stateWatcher: StateFileWatcher?
    private var lastAuthRefresh: Date?
    private var lastSessionIndexRefresh: Date?
    private var lastLogRefresh: Date?
    private var lastStateRefresh: Date?
    private var isRefreshing = false
    private var pendingForceRefresh = false

    init(
        helloSender: HelloSending = CodexHelloSender(),
        healthCheckInterval: TimeInterval = AppViewModel.defaultHealthCheckInterval
    ) {
        self.helloSender = helloSender
        self.healthCheckInterval = healthCheckInterval
        self.logIngestor = SessionLogIngestor(logsURL: URL(fileURLWithPath: "~/.codex/sessions").expandingTildeInPath, tailBytes: Self.logTailBytes)
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
        migrateCodexAccountNumbersIfNeeded()
        refreshActiveEmail()
        applyAssumedResets()
        startHealthChecks()
        startMaintenance()
        startAuthWatcher()
        startSessionIndexWatcher()
        startLogWatcher()
        startStateWatcher()
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

    func refreshFromLogs(force: Bool = false) {
        if isRefreshing {
            pendingForceRefresh = pendingForceRefresh || force
            return
        }
        isRefreshing = true
        lastError = nil
        let authURL = defaultAuthURL()

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
                let identity = try authDecoder.loadActiveAccount(from: authURL)
                let observedAt = authFileModifiedAt() ?? Date()
                updateActiveEmail(identity.email)
                recordAuthObservation(identity, observedAt: observedAt)
                guard let accountIndex = state.accounts.firstIndex(where: { $0.email == identity.email }) else {
                    lastError = "Active account is not configured in Settings."
                    persist()
                    return
                }
                let refreshAt = Date()
                let changes = try await refreshSnapshots(force: force, currentIdentity: identity, observedAt: observedAt, refreshAt: refreshAt)
                guard let activeSnapshot = state.accounts[accountIndex].lastSnapshot else {
                    lastError = "No usage data yet for active account. Run /status once."
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
            let identity = try authDecoder.loadActiveAccount(from: defaultAuthURL())
            recordAuthObservation(identity, observedAt: authFileModifiedAt() ?? Date())
            updateActiveEmail(identity.email)
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
        authWatcher = AuthFileWatcher(authURL: defaultAuthURL()) { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.handleAuthChange()
            }
        }
        authWatcher?.start()
    }

    private func startSessionIndexWatcher() {
        sessionIndexWatcher?.stop()
        sessionIndexWatcher = SessionIndexWatcher(fileURL: defaultSessionIndexURL()) { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.handleSessionIndexChange()
            }
        }
        sessionIndexWatcher?.start()
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
        refreshFromLogs(force: true)
    }

    private func handleSessionIndexChange() {
        let now = Date()
        if let last = lastSessionIndexRefresh, now.timeIntervalSince(last) < 1 {
            return
        }
        lastSessionIndexRefresh = now
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
        currentIdentity: AuthAccountIdentity,
        observedAt: Date,
        refreshAt: Date
    ) async throws -> Int {
        let originalBindings = state.sessionBindings
        let originalObservations = state.authObservations
        let candidateFiles = await candidateLogFiles()
        let configuredEmails = Set(state.accounts.map(\.email))
        var bindings = state.sessionBindings
        var latestByEmail: [String: (binding: SessionAccountBinding, event: TokenCountEvent)] = [:]

        for fileURL in candidateFiles {
            guard let metadata = try await logIngestor.sessionMetadata(in: fileURL) else { continue }
            if let binding = resolveBinding(
                existingBindings: bindings,
                metadata: metadata,
                fileURL: fileURL,
                currentIdentity: currentIdentity,
                observedAt: observedAt
            ) {
                bindings[binding.sessionID] = binding
            }
        }

        bindings = pruneSessionBindings(bindings, configuredEmails: configuredEmails)
        state.sessionBindings = bindings
        pruneAuthObservations()

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

        var changeCount = 0
        var updatedAccounts: [AccountRecord] = []

        for index in state.accounts.indices {
            let email = state.accounts[index].email
            guard let candidate = latestByEmail[email],
                  let snapshot = snapshot(for: candidate.event) else {
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

    private func candidateLogFiles() async -> [URL] {
        let recentFiles = await logIngestor.recentLogFiles(
            referenceDate: Date(),
            lookbackDays: Self.sessionLookbackDays,
            limit: Self.maxRecentLogFiles
        )
        var ordered: [URL] = []
        var seenPaths: Set<String> = []

        for fileURL in recentFiles {
            guard seenPaths.insert(fileURL.path).inserted else { continue }
            ordered.append(fileURL)
        }

        for binding in state.sessionBindings.values.sorted(by: { $0.lastObservedAt > $1.lastObservedAt }) {
            let fileURL = URL(fileURLWithPath: binding.rolloutPath)
            guard FileManager.default.fileExists(atPath: fileURL.path) else { continue }
            guard seenPaths.insert(fileURL.path).inserted else { continue }
            ordered.append(fileURL)
        }

        return ordered
    }

    private func resolveBinding(
        existingBindings: [String: SessionAccountBinding],
        metadata: SessionMetadata,
        fileURL: URL,
        currentIdentity: AuthAccountIdentity,
        observedAt: Date
    ) -> SessionAccountBinding? {
        if var existing = existingBindings[metadata.sessionID] {
            existing.rolloutPath = fileURL.path
            existing.lastObservedAt = Date()
            return existing
        }

        guard let observation = bestAuthObservation(for: metadata.startedAt, currentIdentity: currentIdentity, observedAt: observedAt) else {
            return nil
        }

        return SessionAccountBinding(
            sessionID: metadata.sessionID,
            rolloutPath: fileURL.path,
            email: observation.email,
            subject: observation.subject,
            accountId: observation.accountId,
            startedAt: metadata.startedAt,
            lastObservedAt: Date()
        )
    }

    private func bestAuthObservation(
        for sessionStartedAt: Date,
        currentIdentity: AuthAccountIdentity,
        observedAt: Date
    ) -> AuthObservation? {
        let sorted = state.authObservations.sorted { $0.observedAt < $1.observedAt }
        if let match = sorted.last(where: { observation in
            sessionStartedAt.timeIntervalSince(observation.observedAt) >= -Self.authObservationClockSkewGrace
        }) {
            return match
        }

        if sessionStartedAt.timeIntervalSince(observedAt) >= -Self.authObservationClockSkewGrace {
            return AuthObservation(
                email: currentIdentity.email,
                subject: currentIdentity.subject,
                accountId: currentIdentity.accountId,
                observedAt: observedAt
            )
        }

        return nil
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
        let cutoff = Date().addingTimeInterval(-Self.authObservationRetention)
        state.authObservations = state.authObservations
            .filter { $0.observedAt >= cutoff }
            .suffix(Self.maxAuthObservations)
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

    private func defaultLogsURL() -> URL {
        URL(fileURLWithPath: "~/.codex/sessions").expandingTildeInPath
    }

    private func defaultAuthURL() -> URL {
        URL(fileURLWithPath: "~/.codex/auth.json").expandingTildeInPath
    }

    private func defaultSessionIndexURL() -> URL {
        URL(fileURLWithPath: "~/.codex/session_index.jsonl").expandingTildeInPath
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
    // Safety net in case filesystem events are missed (sleep/wake, log rotation, etc.).
    // Parsing is tail-based so this is intentionally kept reasonably frequent.
    static let defaultHealthCheckInterval: TimeInterval = 5 * 60
    static let logTailBytes: Int = 256 * 1024
    static let sessionLookbackDays: Int = 14
    static let maxRecentLogFiles: Int = 96
    static let maxAuthObservations: Int = 64
    static let authObservationClockSkewGrace: TimeInterval = 5
    static let authObservationRetention: TimeInterval = 45 * 24 * 60 * 60
    static let sessionBindingRetention: TimeInterval = 45 * 24 * 60 * 60
}
