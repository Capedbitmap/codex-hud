import SwiftUI
import CodexHudCore

struct AccountsListView: View {
    @ObservedObject var viewModel: AppViewModel
    private let evaluator = AccountEvaluator()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Accounts")
                .font(Typography.cardTitle)
                .foregroundStyle(Theme.secondary)

            if viewModel.state.accounts.isEmpty {
                Text("Configure accounts in Settings")
                    .font(Typography.label)
                    .foregroundStyle(Theme.muted)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.state.accounts, id: \.email) { account in
                            let status = evaluator.status(for: account)
                            AccountStripItem(
                                account: account,
                                status: status,
                                remainingPercent: remainingPercent(status),
                                isActive: account.email == viewModel.state.activeEmail
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func remainingPercent(_ status: AccountStatus) -> Double? {
        switch status {
        case .available(let state):
            return state.remainingPercent.value
        case .depleted(let state):
            return state.remainingPercent.value
        case .unknown:
            return nil
        }
    }
}

private struct AccountStripItem: View {
    let account: AccountRecord
    let status: AccountStatus
    let remainingPercent: Double?
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("C\(account.codexNumber)")
                    .font(Typography.chip)
                    .foregroundStyle(isActive ? Color.primary : Theme.secondary)
                if isActive {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 6, height: 6)
                }
                Spacer(minLength: 0)
            }

            AccountProgressBar(
                percent: remainingPercent,
                color: statusColor
            )
        }
        .frame(width: 70)
    }

    private var statusColor: Color {
        switch status {
        case .available:
            return Theme.accent
        case .depleted:
            return Theme.critical
        case .unknown:
            return Theme.muted
        }
    }
}

private struct AccountProgressBar: View {
    let percent: Double?
    let color: Color

    var body: some View {
        Capsule()
            .fill(Color.white.opacity(0.2))
            .frame(height: 5)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(color)
                        .frame(
                            width: max(6, proxy.size.width * CGFloat((percent ?? 0) / 100)),
                            height: 5
                        )
                }
            }
    }
}
