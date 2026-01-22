import SwiftUI
import CodexHudCore

struct RecommendationView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        let decision = viewModel.recommendation
        VStack(alignment: .leading, spacing: 8) {
            Text("Recommended Next")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.muted)

            if let account = decision.recommended {
                Text("Codex \(account.codexNumber)")
                    .font(.system(size: 18, weight: .bold))
                Text(account.email)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.muted)
                Text(reasonLabel(decision.reason))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
            } else {
                Text("No recommendation")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
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
