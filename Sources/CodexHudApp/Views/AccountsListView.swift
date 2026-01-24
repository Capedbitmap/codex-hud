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
                        HStack(spacing: 10) {
                            ForEach(viewModel.state.accounts, id: \.email) { account in
                                let status = evaluator.status(for: account)
                            AccountStripItem(
                                account: account,
                                status: status,
                                weeklyRemainingPercent: remainingPercent(status),
                                weeklyTimeRemainingPercent: weeklyTimeRemainingPercent(account, now: context.date),
                                isActive: account.email == viewModel.state.activeEmail,
                                tooltip: tooltip(for: account, status: status, now: context.date),
                                now: context.date
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
            lines.append("Weekly resets: \(formatDate(state.resetsAt))")
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
        if date <= now { return "now" }
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
    let now: Date
    @State private var isHovering = false

    var body: some View {
        let weeklyReset = weeklyResetDate
        let timeText = weeklyReset.map { shortCountdownString(to: $0, now: now) }
        let usageText = weeklyRemainingPercent.map { "\(Int($0))%" }
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
                height: 4,
                trailingText: timeText
            )
            AccountMetricRow(
                systemImage: "chart.bar",
                percent: weeklyRemainingPercent,
                color: usageColor,
                height: 3,
                trailingText: usageText
            )
        }
        .frame(width: 74)
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .popover(isPresented: $isHovering, arrowEdge: .bottom) {
            AccountHoverDetail(
                account: account,
                weeklyRemainingPercent: weeklyRemainingPercent,
                weeklyTimeRemainingPercent: weeklyTimeRemainingPercent,
                weeklyResetDate: weeklyReset,
                now: Date()
            )
            .frame(width: 240, alignment: .leading)
            .padding(8)
        }
    }

    private var usageColor: Color {
        if let weeklyRemainingPercent {
            return Theme.color(forRemainingPercent: weeklyRemainingPercent).opacity(0.9)
        }
        switch status {
        case .unknown:
            return Theme.muted
        case .available, .depleted:
            return Theme.secondary
        }
    }

    private var weeklyResetDate: Date? {
        switch status {
        case .available(let state), .depleted(let state):
            return state.resetsAt
        case .unknown:
            return nil
        }
    }

    private func shortCountdownString(to date: Date, now: Date) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        formatter.zeroFormattingBehavior = .dropAll
        if date <= now { return "now" }
        return formatter.string(from: now, to: date) ?? "—"
    }
}

private struct AccountMetricRow: View {
    let systemImage: String
    let percent: Double?
    let color: Color
    let height: CGFloat
    let trailingText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 8, weight: .regular))
                    .foregroundStyle(Theme.muted)
                Spacer(minLength: 4)
                if let trailingText {
                    Text(trailingText)
                        .font(Typography.meta)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            AccountProgressBar(percent: percent, color: color, height: height)
                .frame(maxWidth: .infinity)
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

private struct AccountHoverDetail: View {
    let account: AccountRecord
    let weeklyRemainingPercent: Double?
    let weeklyTimeRemainingPercent: Double?
    let weeklyResetDate: Date?
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("C\(account.codexNumber) · \(account.email)")
                .font(Typography.meta)
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
                .truncationMode(.middle)

            HoverMetricRow(
                title: "Weekly remaining",
                systemImage: "chart.bar",
                percent: weeklyRemainingPercent,
                color: Theme.color(forRemainingPercent: weeklyRemainingPercent).opacity(0.95),
                trailingText: weeklyRemainingPercent.map { "\(Int($0))%" } ?? "—"
            )

            HoverMetricRow(
                title: "Weekly reset",
                systemImage: "clock",
                percent: weeklyTimeRemainingPercent,
                color: Theme.secondary,
                trailingText: weeklyResetDate.map { countdownString(to: $0, now: now) } ?? "—"
            )

            if let weeklyResetDate {
                Text("Resets \(formatDate(weeklyResetDate))")
                    .font(Typography.meta)
                    .foregroundStyle(Theme.muted)
            } else {
                Text("Resets —")
                    .font(Typography.meta)
                    .foregroundStyle(Theme.muted)
            }
        }
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
}

private struct HoverMetricRow: View {
    let title: String
    let systemImage: String
    let percent: Double?
    let color: Color
    let trailingText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Theme.muted)
                Text(title)
                    .font(Typography.meta)
                    .foregroundStyle(Theme.muted)
                Spacer(minLength: 8)
                Text(trailingText)
                    .font(Typography.meta)
                    .foregroundStyle(Theme.muted)
            }
            Capsule()
                .fill(Color.white.opacity(0.12))
                .frame(height: 6)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(color)
                            .frame(
                                width: max(6, proxy.size.width * CGFloat((percent ?? 0) / 100)),
                                height: 6
                            )
                    }
                }
        }
    }
}
