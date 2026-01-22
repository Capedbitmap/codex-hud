import SwiftUI
import CodexHudCore

struct RecommendationView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        let decision = viewModel.recommendation
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Label("Recommended Next", systemImage: "sparkle")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.secondary)

                if let account = decision.recommended {
                    HStack {
                        Text("Codex \(account.codexNumber)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.readyGradient)
                        Spacer()
                        Text(reasonLabel(decision.reason))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.muted)
                    }
                    Text(account.email)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text("No recommendation")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.secondary)
                }
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
