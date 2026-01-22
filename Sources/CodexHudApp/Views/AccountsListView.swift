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
                    .font(Typography.cardTitle)
                    .foregroundStyle(Theme.secondary)

                if viewModel.state.accounts.isEmpty {
                    Text("Configure accounts in Settings")
                        .font(Typography.label)
                        .foregroundStyle(Theme.muted)
                } else {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(viewModel.state.accounts, id: \.email) { account in
                            AccountChip(
                                account: account,
                                status: evaluator.status(for: account),
                                gradient: statusGradient(evaluator.status(for: account)),
                                label: statusLabel(evaluator.status(for: account)),
                                isActive: account.email == viewModel.state.activeEmail
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
    let isActive: Bool

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(gradient)
                    .frame(width: 10, height: 10)
                if case .available = status {
                    Circle()
                        .fill(gradient)
                        .frame(width: 10, height: 10)
                        .blur(radius: 4)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("C\(account.codexNumber)")
                        .font(Typography.chip)
                        .foregroundStyle(isActive ? Color.primary : Theme.secondary)
                    if isActive {
                        Text("ACTIVE")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(Theme.readyGradient)
                            )
                    }
                }
                Text(label)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
        }
        .padding(8)
        .background(
            GlassSurface(cornerRadius: 12, material: .hudWindow, elevation: isActive ? .raised : .inset, tint: isActive ? Theme.accentTint : nil, animateHighlight: false)
        )
        .animation(AppAnimations.snappy, value: isActive)
    }
}
