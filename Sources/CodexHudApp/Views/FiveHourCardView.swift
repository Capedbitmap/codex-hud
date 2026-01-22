import SwiftUI
import CodexHudCore

struct FiveHourCardView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        let fiveHour = viewModel.activeAccount?.lastSnapshot?.fiveHour
        let usedPercent = fiveHour?.usedPercent

        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Label("5-Hour", systemImage: "timer")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.secondary)

                if let usedPercent {
                    Text("\(Int(usedPercent))% used")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.readyGradient)
                        .monospacedDigit()
                } else {
                    Text("No data")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.secondary)
                }

                if let fiveHour {
                    Text("Resets \(formatDate(fiveHour.resetsAt))")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.muted)
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
