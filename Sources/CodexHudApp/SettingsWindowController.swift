import SwiftUI
import AppKit

@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    func show(viewModel: AppViewModel) {
        if let window {
            window.contentViewController = NSHostingController(rootView: SettingsView(viewModel: viewModel))
            window.makeKeyAndOrderFront(nil)
        } else {
            let controller = NSHostingController(rootView: SettingsView(viewModel: viewModel))
            let window = NSWindow(contentViewController: controller)
            window.title = "Codex HUD Settings"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 680, height: 420))
            window.center()
            window.makeKeyAndOrderFront(nil)
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}
