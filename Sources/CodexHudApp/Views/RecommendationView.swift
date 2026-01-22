import SwiftUI
import CodexHudCore

struct RecommendationView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        let decision = viewModel.recommendation
        VStack(alignment: .leading, spacing: 8) {
            Label("Recommended Next", systemImage: "sparkle")
                .font(Typography.cardTitle)
                .foregroundStyle(Theme.secondary)

            if let account = decision.recommended {
                HStack {
                    Text("Codex \(account.codexNumber)")
                        .font(Typography.cardValue)
                        .foregroundStyle(Theme.accent)
                    Spacer()
                    Text(reasonLabel(decision.reason))
                        .font(Typography.caption)
                        .foregroundStyle(Theme.muted)
                }
                Text(account.email)
                    .font(Typography.label)
                    .foregroundStyle(Theme.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                PriorityListView(
                    accounts: viewModel.priorityList,
                    activeEmail: viewModel.state.activeEmail
                )
            } else {
                Text("No recommendation")
                    .font(Typography.cardValue)
                    .foregroundStyle(Theme.secondary)
            }
        }
    }

    private func reasonLabel(_ reason: RecommendationReason) -> String {
        switch reason {
        case .stickiness:
            return "Staying on active account"
        case .earliestWeeklyReset:
            return "Earliest weekly reset"
        case .allDepleted:
            return "All depleted - soonest reset"
        case .noData:
            return "No data available"
        }
    }
}

private struct PriorityListView: View {
    let accounts: [AccountRecord]
    let activeEmail: String?

    var body: some View {
        Group {
            if accounts.isEmpty {
                EmptyView()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(accounts.enumerated()), id: \.element.email) { index, account in
                            PriorityChip(
                                rank: index + 1,
                                codexNumber: account.codexNumber,
                                isActive: account.email == activeEmail
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct PriorityChip: View {
    let rank: Int
    let codexNumber: Int
    let isActive: Bool

    var body: some View {
        let label = "\(rank)·C\(codexNumber)"
        return Text(label)
            .font(Typography.caption)
            .foregroundStyle(isActive ? Theme.secondary : Theme.muted)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Color.white.opacity(isActive ? 0.16 : 0.08))
            )
    }
}
