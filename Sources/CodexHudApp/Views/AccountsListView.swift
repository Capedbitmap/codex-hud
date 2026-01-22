import SwiftUI
import CodexHudCore

struct AccountsListView: View {
    @ObservedObject var viewModel: AppViewModel
    private let evaluator = AccountEvaluator()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Accounts")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.muted)

            if viewModel.state.accounts.isEmpty {
                Text("Configure accounts in Settings")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.muted)
            } else {
                ForEach(viewModel.state.accounts, id: \.email) { account in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(statusColor(evaluator.status(for: account)))
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Codex \(account.codexNumber)")
                                .font(.system(size: 12, weight: .semibold))
                            Text(account.email)
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        Text(statusLabel(evaluator.status(for: account)))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.muted)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    private func statusColor(_ status: AccountStatus) -> Color {
        switch status {
        case .available:
            return Theme.accent
        case .depleted:
            return Theme.critical
        case .unknown:
            return Theme.muted
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
