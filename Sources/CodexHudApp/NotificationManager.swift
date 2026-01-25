import Foundation
import UserNotifications
import CodexHudCore

@MainActor
final class NotificationManager {
    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        if let granted = try? await center.requestAuthorization(options: [.alert, .sound]) {
            return granted
        }
        return false
    }

    func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    func send(events: [NotificationEvent], recommendation: RecommendationDecision) {
        guard !events.isEmpty else { return }

        Task {
            let center = UNUserNotificationCenter.current()
            let granted = try? await center.requestAuthorization(options: [.alert, .sound])
            guard granted == true else { return }
            for event in events {
                await enqueue(event: event, recommendation: recommendation, center: center)
            }
        }
    }

    func sendWeeklyResetReminder(_ reminder: WeeklyResetReminderEvent) {
        Task {
            let center = UNUserNotificationCenter.current()
            let granted = try? await center.requestAuthorization(options: [.alert, .sound])
            guard granted == true else { return }
            let content = UNMutableNotificationContent()
            content.title = "Codex HUD: Weekly Reset Ready"
            let date = DateFormatter.localizedString(from: reminder.resetsAt, dateStyle: .medium, timeStyle: .short)
            content.body = "Codex \(reminder.codexNumber) (\(reminder.accountEmail)) reset at \(date). Log in and send a message to start the weekly window."
            content.sound = .default
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            try? await center.add(request)
        }
    }

    func sendHelloSentNotification(accountEmail: String, codexNumber: Int, sentAt: Date) {
        Task {
            let center = UNUserNotificationCenter.current()
            let granted = try? await center.requestAuthorization(options: [.alert, .sound])
            guard granted == true else { return }
            let content = UNMutableNotificationContent()
            content.title = "Codex HUD: 5-Hour Window Started"
            let time = DateFormatter.localizedString(from: sentAt, dateStyle: .none, timeStyle: .short)
            content.body = "Hello sent at \(time) for Codex \(codexNumber) (\(accountEmail))."
            content.sound = .default
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            try? await center.add(request)
        }
    }

    private func enqueue(event: NotificationEvent, recommendation: RecommendationDecision, center: UNUserNotificationCenter) async {
        let content = UNMutableNotificationContent()
        content.title = title(for: event)
        content.body = body(for: event, recommendation: recommendation)
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await center.add(request)
    }

    private func title(for event: NotificationEvent) -> String {
        let window = event.window == .weekly ? "Weekly" : "5-Hour"
        let level: String
        switch event.level {
        case .critical:
            level = "Critical"
        case .warning:
            level = "Warning"
        case .caution:
            level = "Caution"
        case .normal:
            level = "Notice"
        }
        return "Codex HUD: \(window) \(level)"
    }

    private func body(for event: NotificationEvent, recommendation: RecommendationDecision) -> String {
        let remaining = Int(event.remainingPercent.value)
        let prefix = "Codex \(event.codexNumber) (\(event.accountEmail)) has \(remaining)% remaining."
        guard let next = recommendation.recommended else { return prefix }
        if event.level != .critical || next.email == event.accountEmail {
            return prefix
        }
        return "\(prefix) Switch to Codex \(next.codexNumber) (\(next.email))."
    }
}
