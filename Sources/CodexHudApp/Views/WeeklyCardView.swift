import SwiftUI
import CodexHudCore

struct WeeklyCardView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        let weekly = viewModel.activeAccount?.lastSnapshot?.weekly
        let remaining = viewModel.weeklyRemainingPercent
        let level = weeklyLevel(remaining)
        let color = Theme.color(forRemainingPercent: remaining?.value)

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Weekly", systemImage: "clock.arrow.circlepath")
                    .font(Typography.cardTitle)
                    .foregroundStyle(Theme.secondary)
                Spacer()
                if level == .critical {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.critical)
                        .symbolRenderingMode(.hierarchical)
                }
            }

            if let remaining {
                HStack(spacing: 16) {
                    PremiumCircularGauge(progress: remaining.value, tint: color)
                        .frame(width: 96, height: 96)

                    VStack(alignment: .leading, spacing: 6) {
                        if let weekly {
                            let details = resetDetails("weekly", date: weekly.resetsAt)
                            let countdown = countdownString(to: weekly.resetsAt)
                            Text("Resets \(formatDate(weekly.resetsAt))")
                                .font(Typography.meta)
                                .foregroundStyle(Theme.muted)
                                .help(details)
                            Text("In \(countdown)")
                                .font(Typography.caption)
                                .foregroundStyle(Theme.muted)
                            if weekly.isStale {
                                Text("Stale until refreshed")
                                    .font(Typography.caption)
                                    .foregroundStyle(Theme.warning)
                            }
                        }
                    }
                    Spacer()
                }
            } else {
                Text("No data")
                    .font(Typography.cardValue)
                    .foregroundStyle(Theme.secondary)
            }
        }
    }

    private func weeklyLevel(_ remaining: Percent?) -> ThresholdLevel {
        guard let remaining else { return .normal }
        if remaining <= UsageThresholds.default.depleted { return .critical }
        if remaining <= UsageThresholds.default.warning { return .warning }
        return .normal
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func resetDetails(_ label: String, date: Date) -> String {
        let countdown = countdownString(to: date)
        return "\(label.capitalized) resets: \(formatDate(date)) (\(countdown))"
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
