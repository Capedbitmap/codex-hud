import SwiftUI
import CodexHudCore

struct MenuBarView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HeaderView(viewModel: viewModel)

            WeeklyCardView(viewModel: viewModel)

            if viewModel.shouldShowFiveHour {
                FiveHourCardView(viewModel: viewModel)
            }

            RecommendationView(viewModel: viewModel)

            AccountsListView(viewModel: viewModel)

            FooterActionsView(
                refreshAction: { viewModel.refreshFromLogs() },
                settingsAction: { openSettingsWindow() },
                quitAction: { NSApp.terminate(nil) }
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.background)
                .background(.ultraThinMaterial)
        )
        .frame(width: 360)
    }

    private func openSettingsWindow() {
        let settingsSelector = Selector(("showSettingsWindow:"))
        if NSApp.sendAction(settingsSelector, to: nil, from: nil) {
            return
        }
        _ = NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }
}

private struct HeaderView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Codex HUD")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Text("v0")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.muted)
            }
            Text(activeLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.muted)
            if let lastRefresh = viewModel.state.lastRefresh {
                Text("Last refresh: \(formatDate(lastRefresh))")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
            }
            if let error = viewModel.lastError {
                Text(error)
                    .font(.system(size: 11, weight: .semibold))
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
        HStack(spacing: 12) {
            Button("Refresh Now", action: refreshAction)
                .buttonStyle(.borderedProminent)
            Button("Settings", action: settingsAction)
                .buttonStyle(.bordered)
            Spacer()
            Button("Quit", action: quitAction)
                .buttonStyle(.borderless)
                .foregroundStyle(Theme.muted)
        }
        .font(.system(size: 12, weight: .medium))
    }
}
