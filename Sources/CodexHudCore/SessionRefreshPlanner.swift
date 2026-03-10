import Foundation

public struct SessionRefreshPlan: Equatable, Sendable {
    public let bindings: [String: SessionAccountBinding]
    public let activeEmail: String?
    public let candidateRolloutPaths: [String]

    public init(
        bindings: [String: SessionAccountBinding],
        activeEmail: String?,
        candidateRolloutPaths: [String]
    ) {
        self.bindings = bindings
        self.activeEmail = activeEmail
        self.candidateRolloutPaths = candidateRolloutPaths
    }
}

public struct SessionRefreshPlanner {
    public let bindingRetention: TimeInterval
    public let authObservationClockSkewGrace: TimeInterval
    public let maxAuthObservations: Int

    public init(
        bindingRetention: TimeInterval = 45 * 24 * 60 * 60,
        authObservationClockSkewGrace: TimeInterval = 5,
        maxAuthObservations: Int = 64
    ) {
        self.bindingRetention = bindingRetention
        self.authObservationClockSkewGrace = authObservationClockSkewGrace
        self.maxAuthObservations = maxAuthObservations
    }

    public func plan(
        state: AppState,
        configuredEmails: Set<String>,
        recentThreads: [CodexThreadActivity],
        metadataByRolloutPath: [String: SessionMetadata],
        currentIdentity: AuthAccountIdentity?,
        observedAt: Date,
        now: Date = Date()
    ) -> SessionRefreshPlan {
        var bindings = pruneSessionBindings(
            state.sessionBindings,
            configuredEmails: configuredEmails,
            now: now
        )
        let observations = pruneAuthObservations(state.authObservations)

        for thread in recentThreads {
            guard let metadata = metadataByRolloutPath[thread.rolloutPath] else { continue }
            if var existing = bindings[metadata.sessionID] {
                existing.rolloutPath = thread.rolloutPath
                existing.lastObservedAt = now
                bindings[metadata.sessionID] = existing
                continue
            }

            guard let observation = bestAuthObservation(
                observations: observations,
                sessionStartedAt: metadata.startedAt,
                currentIdentity: currentIdentity,
                observedAt: observedAt
            ) else {
                continue
            }

            bindings[metadata.sessionID] = SessionAccountBinding(
                sessionID: metadata.sessionID,
                rolloutPath: thread.rolloutPath,
                email: observation.email,
                subject: observation.subject,
                accountId: observation.accountId,
                startedAt: metadata.startedAt,
                lastObservedAt: now
            )
        }

        bindings = pruneSessionBindings(bindings, configuredEmails: configuredEmails, now: now)

        let activeEmail = latestMappedEmail(
            recentThreads: recentThreads,
            bindings: bindings,
            configuredEmails: configuredEmails
        ) ?? fallbackActiveEmail(
            state: state,
            currentIdentity: currentIdentity,
            configuredEmails: configuredEmails
        )

        return SessionRefreshPlan(
            bindings: bindings,
            activeEmail: activeEmail,
            candidateRolloutPaths: candidateRolloutPaths(recentThreads: recentThreads, bindings: bindings)
        )
    }

    private func latestMappedEmail(
        recentThreads: [CodexThreadActivity],
        bindings: [String: SessionAccountBinding],
        configuredEmails: Set<String>
    ) -> String? {
        var latest: (updatedAt: Date, email: String)?

        for thread in recentThreads {
            guard let binding = bindings[thread.sessionID],
                  configuredEmails.contains(binding.email) else {
                continue
            }
            if let current = latest {
                if thread.updatedAt > current.updatedAt {
                    latest = (thread.updatedAt, binding.email)
                }
            } else {
                latest = (thread.updatedAt, binding.email)
            }
        }

        return latest?.email
    }

    private func fallbackActiveEmail(
        state: AppState,
        currentIdentity: AuthAccountIdentity?,
        configuredEmails: Set<String>
    ) -> String? {
        if let currentIdentity, configuredEmails.contains(currentIdentity.email) {
            return currentIdentity.email
        }
        if let existing = state.activeEmail, configuredEmails.contains(existing) {
            return existing
        }
        return nil
    }

    private func candidateRolloutPaths(
        recentThreads: [CodexThreadActivity],
        bindings: [String: SessionAccountBinding]
    ) -> [String] {
        var ordered: [String] = []
        var seen: Set<String> = []

        for thread in recentThreads {
            guard seen.insert(thread.rolloutPath).inserted else { continue }
            ordered.append(thread.rolloutPath)
        }

        let sortedBindings = bindings.values.sorted { $0.lastObservedAt > $1.lastObservedAt }
        for binding in sortedBindings {
            guard seen.insert(binding.rolloutPath).inserted else { continue }
            ordered.append(binding.rolloutPath)
        }

        return ordered
    }

    private func bestAuthObservation(
        observations: [AuthObservation],
        sessionStartedAt: Date,
        currentIdentity: AuthAccountIdentity?,
        observedAt: Date
    ) -> AuthObservation? {
        let sorted = observations.sorted { $0.observedAt < $1.observedAt }
        if let match = sorted.last(where: { observation in
            sessionStartedAt.timeIntervalSince(observation.observedAt) >= -authObservationClockSkewGrace
        }) {
            return match
        }

        guard let currentIdentity,
              sessionStartedAt.timeIntervalSince(observedAt) >= -authObservationClockSkewGrace else {
            return nil
        }

        return AuthObservation(
            email: currentIdentity.email,
            subject: currentIdentity.subject,
            accountId: currentIdentity.accountId,
            observedAt: observedAt
        )
    }

    private func pruneAuthObservations(_ observations: [AuthObservation]) -> [AuthObservation] {
        Array(observations.suffix(maxAuthObservations))
    }

    private func pruneSessionBindings(
        _ bindings: [String: SessionAccountBinding],
        configuredEmails: Set<String>,
        now: Date
    ) -> [String: SessionAccountBinding] {
        let cutoff = now.addingTimeInterval(-bindingRetention)
        return bindings.filter { _, binding in
            configuredEmails.contains(binding.email)
                && binding.lastObservedAt >= cutoff
                && FileManager.default.fileExists(atPath: binding.rolloutPath)
        }
    }
}
