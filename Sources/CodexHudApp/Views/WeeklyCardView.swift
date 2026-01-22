import SwiftUI
import CodexHudCore

struct WeeklyCardView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        let weekly = viewModel.activeAccount?.lastSnapshot?.weekly
        let remaining = viewModel.weeklyRemainingPercent
        let level = weeklyLevel(remaining)
        let gradient = Theme.gradient(for: level)

        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Weekly", systemImage: "clock.arrow.circlepath")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.secondary)
                    Spacer()
                    if level == .critical {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.criticalGradient)
                            .symbolRenderingMode(.hierarchical)
                    }
                }

                if let remaining {
                    Text("\(Int(remaining.value))%")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(gradient)
                        .monospacedDigit()
                } else {
                    Text("No data")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.secondary)
                }

                if let weekly {
                    Text("Resets \(formatDate(weekly.resetsAt))")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.muted)
                    if weekly.isStale {
                        Text("Stale until refreshed")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.warningGradient)
                    }
                }
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
}
