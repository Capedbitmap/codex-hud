import SwiftUI
import CodexHudCore

struct WeeklyCardView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        let weekly = viewModel.activeAccount?.lastSnapshot?.weekly
        let remaining = viewModel.weeklyRemainingPercent
        let level = weeklyLevel(remaining)
        let gradient = Theme.gradient(for: level)
        let glow = Theme.glow(for: level)

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
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.12), lineWidth: 8)
                            Circle()
                                .trim(from: 0, to: CGFloat(remaining.value / 100))
                                .stroke(gradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .shadow(color: glow.opacity(0.5), radius: 6, x: 0, y: 3)
                            Text("\(Int(remaining.value))%")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(gradient)
                                .monospacedDigit()
                        }
                        .frame(width: 92, height: 92)

                        VStack(alignment: .leading, spacing: 6) {
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
                        Spacer()
                    }
                } else {
                    Text("No data")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.secondary)
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
