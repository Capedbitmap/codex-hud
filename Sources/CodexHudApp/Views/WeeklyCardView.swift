import SwiftUI
import CodexHudCore

struct WeeklyCardView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        let weekly = viewModel.activeAccount?.lastSnapshot?.weekly
        let remaining = viewModel.weeklyRemainingPercent
        let accent = weeklyAccent(remaining)

        VStack(alignment: .leading, spacing: 8) {
            Text("Weekly")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.muted)

            if let remaining {
                Text("\(Int(remaining.value))% remaining")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(accent)
            } else {
                Text("No data")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }

            if let weekly {
                Text("Reset: \(formatDate(weekly.resetsAt))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.muted)
                if weekly.isStale {
                    Text("Stale until refreshed")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.warning)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(accent.opacity(0.25), lineWidth: 1)
                )
        )
    }

    private func weeklyAccent(_ remaining: Percent?) -> Color {
        guard let remaining else { return Theme.accent }
        if remaining <= UsageThresholds.default.depleted { return Theme.critical }
        if remaining <= UsageThresholds.default.warning { return Theme.warning }
        return Theme.accent
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
