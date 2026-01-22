import SwiftUI
import CodexHudCore

struct FiveHourCardView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        let fiveHour = viewModel.activeAccount?.lastSnapshot?.fiveHour
        let remainingPercent = fiveHour.map { max(0, min(100, 100 - $0.usedPercent)) }

        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Label("5-Hour", systemImage: "timer")
                    .font(Typography.cardTitle)
                    .foregroundStyle(Theme.secondary)

                if let remainingPercent {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(Int(remainingPercent))% remaining")
                            .font(Typography.cardValue)
                            .foregroundStyle(Theme.readyGradient)
                            .monospacedDigit()

                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 6)
                            .overlay {
                                GeometryReader { proxy in
                                    Capsule()
                                        .fill(Theme.readyGradient)
                                        .frame(width: max(6, proxy.size.width * CGFloat(remainingPercent / 100)), height: 6)
                                }
                            }
                    }
                } else {
                    Text("No data")
                        .font(Typography.cardValue)
                        .foregroundStyle(Theme.secondary)
                }

                if let fiveHour {
                    Text("Resets \(formatDate(fiveHour.resetsAt))")
                        .font(Typography.meta)
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
