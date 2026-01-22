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
