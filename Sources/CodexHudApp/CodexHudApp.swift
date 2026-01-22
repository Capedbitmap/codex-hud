import SwiftUI
import CodexHudCore

@main
struct CodexHudApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        MenuBarExtra("Codex HUD", systemImage: "circle.grid.2x2") {
            MenuBarView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(viewModel: viewModel)
        }
    }
}
