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
                                isActive: account.email == viewModel.state.activeEmail,
                                tooltip: tooltip(for: account, status: status)
                            )
                        }
                    }
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
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

    private func tooltip(for account: AccountRecord, status: AccountStatus) -> String {
        var lines: [String] = []
        switch status {
        case .available(let state), .depleted(let state):
            lines.append("Weekly resets: \(formatDate(state.resetsAt)) (\(countdownString(to: state.resetsAt)))")
        case .unknown:
            lines.append("Weekly resets: no data")
        }
        if account.email == viewModel.state.activeEmail, let fiveHour = account.lastSnapshot?.fiveHour {
            lines.append("5-hour resets: \(formatDate(fiveHour.resetsAt)) (\(countdownString(to: fiveHour.resetsAt)))")
        }
        return lines.joined(separator: "\n")
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func countdownString(to date: Date) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: Date(), to: date) ?? "soon"
    }
}

private struct AccountStripItem: View {
    let account: AccountRecord
    let status: AccountStatus
    let remainingPercent: Double?
    let isActive: Bool
    let tooltip: String
    @State private var isHovering = false

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
        .onHover { hovering in
            isHovering = hovering
        }
        .popover(isPresented: $isHovering, arrowEdge: .bottom) {
            HoverTooltip(text: tooltip)
                .frame(width: 200, alignment: .leading)
                .padding(6)
        }
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
