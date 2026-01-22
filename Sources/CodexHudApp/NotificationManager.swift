import Foundation
import UserNotifications
import CodexHudCore

@MainActor
final class NotificationManager {
    func send(events: [NotificationEvent], recommendation: RecommendationDecision) {
        guard !events.isEmpty else { return }
        guard isRunningInAppBundle else { return }

        Task {
            let center = UNUserNotificationCenter.current()
            let granted = try? await center.requestAuthorization(options: [.alert, .sound])
            guard granted == true else { return }
            for event in events {
                enqueue(event: event, recommendation: recommendation, center: center)
            }
        }
    }

    private var isRunningInAppBundle: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    private func enqueue(event: NotificationEvent, recommendation: RecommendationDecision, center: UNUserNotificationCenter) {
        let content = UNMutableNotificationContent()
        content.title = title(for: event)
        content.body = body(for: event, recommendation: recommendation)
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request)
    }

    private func title(for event: NotificationEvent) -> String {
        let window = event.window == .weekly ? "Weekly" : "5-Hour"
        let level = event.level == .critical ? "Critical" : "Warning"
        return "Codex HUD: \(window) \(level)"
    }

    private func body(for event: NotificationEvent, recommendation: RecommendationDecision) -> String {
        let remaining = Int(event.remainingPercent.value)
        let prefix = "Codex \(event.codexNumber) (\(event.accountEmail)) has \(remaining)% remaining."
        guard let next = recommendation.recommended else { return prefix }
        if next.email == event.accountEmail {
            return prefix
        }
        return "\(prefix) Switch to Codex \(next.codexNumber) (\(next.email))."
    }
}
