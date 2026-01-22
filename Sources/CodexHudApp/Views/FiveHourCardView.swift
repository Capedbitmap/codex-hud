import SwiftUI
import CodexHudCore

struct FiveHourCardView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        let fiveHour = viewModel.activeAccount?.lastSnapshot?.fiveHour
        let usedPercent = fiveHour?.usedPercent

        VStack(alignment: .leading, spacing: 8) {
            Text("5-Hour")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.muted)

            if let usedPercent {
                Text("\(Int(usedPercent))% used")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.accent)
            } else {
                Text("No data")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }

            if let fiveHour {
                Text("Reset: \(formatDate(fiveHour.resetsAt))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
