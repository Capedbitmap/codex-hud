import SwiftUI
import CodexHudCore

struct AccountsListView: View {
    @ObservedObject var viewModel: AppViewModel
    private let evaluator = AccountEvaluator()

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Accounts")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.secondary)

                if viewModel.state.accounts.isEmpty {
                    Text("Configure accounts in Settings")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.muted)
                } else {
                    ForEach(viewModel.state.accounts, id: \.email) { account in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(statusGradient(evaluator.status(for: account)))
                                .frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Codex \(account.codexNumber)")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                Text(account.email)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            Text(statusLabel(evaluator.status(for: account)))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Theme.muted)
                        }
                        if account.email != viewModel.state.accounts.last?.email {
                            GlassDivider()
                        }
                    }
                }
            }
        }
    }

    private func statusGradient(_ status: AccountStatus) -> LinearGradient {
        switch status {
        case .available:
            return Theme.readyGradient
        case .depleted:
            return Theme.criticalGradient
        case .unknown:
            return LinearGradient(colors: [Theme.secondary, Theme.muted], startPoint: .top, endPoint: .bottom)
        }
    }

    private func statusLabel(_ status: AccountStatus) -> String {
        switch status {
        case .available:
            return "Ready"
        case .depleted:
            return "Depleted"
        case .unknown:
            return "Unknown"
        }
    }
}
