import SwiftUI
import CodexHudCore

struct FiveHourCardView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        let fiveHour = viewModel.activeAccount?.lastSnapshot?.fiveHour
        let remainingPercent = fiveHour.map { max(0, min(100, 100 - $0.usedPercent)) }
        let color = Theme.color(forRemainingPercent: remainingPercent)

        VStack(alignment: .leading, spacing: 8) {
            Label("5-Hour", systemImage: "timer")
                .font(Typography.cardTitle)
                .foregroundStyle(Theme.secondary)

            if let remainingPercent {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(Int(remainingPercent))% remaining")
                        .font(Typography.metric)
                        .foregroundStyle(color)
                        .monospacedDigit()

                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 6)
                            .overlay {
                                GeometryReader { proxy in
                                    Capsule()
                                        .fill(color)
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
                let details = resetDetails("5-hour", date: fiveHour.resetsAt)
                let countdown = countdownString(to: fiveHour.resetsAt)
                Text("Resets \(formatDate(fiveHour.resetsAt))")
                    .font(Typography.meta)
                    .foregroundStyle(Theme.muted)
                    .help(details)
                Text("In \(countdown)")
                    .font(Typography.caption)
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
