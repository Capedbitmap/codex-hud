import SwiftUI
import CodexHudCore

struct MenuBarView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HeaderView(viewModel: viewModel)
            AccountsListView(viewModel: viewModel)

            GlassDivider()

            WeeklyCardView(viewModel: viewModel)

            if viewModel.shouldShowFiveHour {
                GlassDivider()
                FiveHourCardView(viewModel: viewModel)
            }

            GlassDivider()

            RecommendationView(viewModel: viewModel)

            FooterActionsView(
                refreshAction: { viewModel.refreshFromLogs() },
                settingsAction: { SettingsWindowController.shared.show(viewModel: viewModel) },
                quitAction: { NSApp.terminate(nil) }
            )
        }
        .padding(18)
        .background(
            GlassSurface(cornerRadius: 26, material: .hudWindow, elevation: .standard, tint: nil, animateHighlight: false)
        )
        .frame(width: 460)
    }
}

private struct HeaderView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Codex HUD", systemImage: "entry.lever.keypad")
                    .font(Typography.cardValue)
                    .symbolRenderingMode(.hierarchical)
                Spacer()
                if let active = viewModel.activeAccount {
                    Text("Codex \(active.codexNumber)")
                        .font(Typography.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            GlassSurface(cornerRadius: 10, material: .hudWindow, elevation: .inset, tint: Theme.accentTint, animateHighlight: false)
                        )
                }
            }
            Text(activeLabel)
                .font(Typography.label)
                .foregroundStyle(Theme.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            if let lastRefresh = viewModel.state.lastRefresh {
                Text("Last refresh: \(formatDate(lastRefresh))")
                    .font(Typography.meta)
                    .foregroundStyle(Theme.muted)
            }
            if let error = viewModel.lastError {
                Text(error)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.critical)
            }
        }
    }

    private var activeLabel: String {
        if let active = viewModel.activeAccount {
            return "Active: Codex \(active.codexNumber) • \(active.email)"
        }
        return "Active: not detected"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private struct FooterActionsView: View {
    let refreshAction: () -> Void
    let settingsAction: () -> Void
    let quitAction: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            GlassDivider()
            HStack(spacing: 12) {
                IconButton(icon: "arrow.clockwise", help: "Refresh", action: refreshAction)
                IconButton(icon: "gearshape", help: "Settings", action: settingsAction)
                Spacer()
                IconButton(icon: "power", help: "Quit", action: quitAction)
            }
        }
    }
}
