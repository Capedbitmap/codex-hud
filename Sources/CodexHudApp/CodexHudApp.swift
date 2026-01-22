import SwiftUI
import CodexHudCore

@main
struct CodexHudApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        MenuBarExtra("Codex HUD", systemImage: "entry.lever.keypad") {
            MenuBarView(viewModel: viewModel)
                .containerBackground(.ultraThinMaterial, for: .window)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(viewModel: viewModel)
                .containerBackground(.ultraThinMaterial, for: .window)
        }
    }
}
