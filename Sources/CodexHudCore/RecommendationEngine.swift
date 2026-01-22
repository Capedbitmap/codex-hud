import Foundation

public enum RecommendationReason: Equatable {
    case stickiness(activeEmail: String)
    case earliestWeeklyReset
    case allDepleted
    case noData
}

public struct RecommendationDecision: Equatable {
    public let recommended: AccountRecord?
    public let reason: RecommendationReason
}

public struct RecommendationEngine {
    public let thresholds: UsageThresholds
    private let evaluator: AccountEvaluator

    public init(thresholds: UsageThresholds = .default) {
        self.thresholds = thresholds
        self.evaluator = AccountEvaluator(thresholds: thresholds)
    }

    public func recommend(accounts: [AccountRecord], activeEmail: String?) -> RecommendationDecision {
        if let activeEmail, let activeAccount = accounts.first(where: { $0.email == activeEmail }) {
            if case .available = evaluator.status(for: activeAccount) {
                return RecommendationDecision(recommended: activeAccount, reason: .stickiness(activeEmail: activeEmail))
            }
        }

        let evaluated = accounts.compactMap { account -> (AccountRecord, AccountStatus)? in
            let status = evaluator.status(for: account)
            switch status {
            case .unknown:
                return nil
            case .available, .depleted:
                return (account, status)
            }
        }

        let available = evaluated.compactMap { (account, status) -> (AccountRecord, WeeklyState)? in
            if case let .available(state) = status {
                return (account, state)
            }
            return nil
        }

        if let winner = pickEarliestReset(from: available) {
            return RecommendationDecision(recommended: winner.account, reason: .earliestWeeklyReset)
        }

        let depleted = evaluated.compactMap { (account, status) -> (AccountRecord, WeeklyState)? in
            if case let .depleted(state) = status {
                return (account, state)
            }
            return nil
        }

        if let winner = pickEarliestReset(from: depleted) {
            return RecommendationDecision(recommended: winner.account, reason: .allDepleted)
        }

        return RecommendationDecision(recommended: nil, reason: .noData)
    }

    private func pickEarliestReset(from candidates: [(AccountRecord, WeeklyState)]) -> (account: AccountRecord, state: WeeklyState)? {
        guard let first = candidates.first else { return nil }
        let sorted = candidates.sorted { lhs, rhs in
            if lhs.1.resetsAt != rhs.1.resetsAt {
                return lhs.1.resetsAt < rhs.1.resetsAt
            }
            return lhs.1.remainingPercent > rhs.1.remainingPercent
        }
        return sorted.first ?? first
    }
}
