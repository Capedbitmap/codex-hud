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
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(viewModel.state.accounts, id: \.email) { account in
                                let status = evaluator.status(for: account)
                                AccountStripItem(
                                    account: account,
                                    status: status,
                                    weeklyRemainingPercent: remainingPercent(status),
                                    weeklyTimeRemainingPercent: weeklyTimeRemainingPercent(account, now: context.date),
                                    isActive: account.email == viewModel.state.activeEmail,
                                    tooltip: tooltip(for: account, status: status, now: context.date)
                                )
                            }
                        }
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
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

    private func tooltip(for account: AccountRecord, status: AccountStatus, now: Date) -> String {
        var lines: [String] = []
        lines.append("Email: \(account.email)")
        switch status {
        case .available(let state), .depleted(let state):
            lines.append("Weekly resets: \(formatDate(state.resetsAt)) (\(countdownString(to: state.resetsAt, now: now)))")
        case .unknown:
            lines.append("Weekly resets: no data")
        }
        if account.email == viewModel.state.activeEmail, let fiveHour = account.lastSnapshot?.fiveHour {
            lines.append("5-hour resets: \(formatDate(fiveHour.resetsAt)) (\(countdownString(to: fiveHour.resetsAt, now: now)))")
        }
        return lines.joined(separator: "\n")
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func countdownString(to date: Date, now: Date) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: now, to: date) ?? "soon"
    }

    private func weeklyTimeRemainingPercent(_ account: AccountRecord, now: Date) -> Double? {
        guard let weekly = account.lastSnapshot?.weekly else { return nil }
        let totalSeconds = Double(weekly.windowMinutes) * 60
        guard totalSeconds > 0 else { return nil }
        let remainingSeconds = weekly.resetsAt.timeIntervalSince(now)
        let ratio = max(0, min(1, remainingSeconds / totalSeconds))
        return ratio * 100
    }
}

private struct AccountStripItem: View {
    let account: AccountRecord
    let status: AccountStatus
    let weeklyRemainingPercent: Double?
    let weeklyTimeRemainingPercent: Double?
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

            AccountMetricRow(
                systemImage: "clock",
                percent: weeklyTimeRemainingPercent,
                color: Theme.secondary,
                height: 4
            )
            AccountMetricRow(
                systemImage: "chart.bar",
                percent: weeklyRemainingPercent,
                color: statusColor.opacity(0.9),
                height: 3
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

private struct AccountMetricRow: View {
    let systemImage: String
    let percent: Double?
    let color: Color
    let height: CGFloat

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 8, weight: .regular))
                .foregroundStyle(Theme.muted)
            AccountProgressBar(percent: percent, color: color, height: height)
        }
    }
}

private struct AccountProgressBar: View {
    let percent: Double?
    let color: Color
    let height: CGFloat

    var body: some View {
        Capsule()
            .fill(Color.white.opacity(0.2))
            .frame(height: height)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(color)
                        .frame(
                            width: max(6, proxy.size.width * CGFloat((percent ?? 0) / 100)),
                            height: height
                        )
                }
            }
    }
}
