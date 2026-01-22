import SwiftUI
import CodexHudCore

struct AccountsListView: View {
    @ObservedObject var viewModel: AppViewModel
    private let evaluator = AccountEvaluator()
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

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
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(viewModel.state.accounts, id: \.email) { account in
                            AccountChip(
                                account: account,
                                status: evaluator.status(for: account),
                                gradient: statusGradient(evaluator.status(for: account)),
                                label: statusLabel(evaluator.status(for: account))
                            )
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

private struct AccountChip: View {
    let account: AccountRecord
    let status: AccountStatus
    let gradient: LinearGradient
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(gradient)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text("C\(account.codexNumber)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondary)
            }
            Spacer()
        }
        .padding(8)
        .background(
            GlassSurface(cornerRadius: 12, material: .hudWindow, highlightOpacity: 0.25, strokeOpacity: 0.4)
        )
    }
}
