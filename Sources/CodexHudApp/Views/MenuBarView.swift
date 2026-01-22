import SwiftUI
import CodexHudCore

struct MenuBarView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)

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
                settingsAction: { SettingsWindowController.shared.show(viewModel: viewModel) },
                quitAction: { NSApp.terminate(nil) }
            )
        }
        .padding(16)
        .background(
            shape
                .fill(.ultraThinMaterial)
                .overlay(shape.fill(Theme.background).opacity(0.35))
                .overlay(shape.stroke(Theme.glassStroke, lineWidth: 1))
                .shadow(color: Theme.glassShadow, radius: 16, x: 0, y: 8)
        )
        .frame(width: 340)
    }
}

private struct HeaderView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Codex HUD", systemImage: "entry.lever.keypad")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .symbolRenderingMode(.hierarchical)
                Spacer()
                Text("v0")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondary)
            }
            Text(activeLabel)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            if let lastRefresh = viewModel.state.lastRefresh {
                Text("Last refresh: \(formatDate(lastRefresh))")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.muted)
            }
            if let error = viewModel.lastError {
                Text(error)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.criticalGradient)
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
            Button("Refresh", action: refreshAction)
                .buttonStyle(GlassButtonStyle())
            Button("Settings", action: settingsAction)
                .buttonStyle(GlassButtonStyle())
            Spacer()
            Button("Quit", action: quitAction)
                .buttonStyle(GlassButtonStyle())
                .foregroundStyle(Theme.secondary)
        }
        .font(.system(size: 12, weight: .semibold, design: .rounded))
    }
}
