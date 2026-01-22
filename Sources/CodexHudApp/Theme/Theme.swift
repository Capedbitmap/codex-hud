import SwiftUI
import CodexHudCore

enum Theme {
    static let glassStroke = LinearGradient(
        colors: [Color.white.opacity(0.65), Color.white.opacity(0.08)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let glassShadow = Color.black.opacity(0.2)
    static let muted = Color.primary.opacity(0.75)
    static let secondary = Color.primary.opacity(0.92)

    static let accent = Color.primary
    static let healthy = Color(red: 0.22, green: 0.65, blue: 0.45)
    static let caution = Color(red: 0.82, green: 0.7, blue: 0.22)
    static let warning = Color(red: 0.78, green: 0.55, blue: 0.2)
    static let critical = Color(red: 0.78, green: 0.33, blue: 0.36)

    static func color(for level: ThresholdLevel) -> Color {
        switch level {
        case .normal:
            return Color.primary
        case .warning:
            return warning
        case .critical:
            return critical
        }
    }

    static func color(forRemainingPercent remaining: Double?) -> Color {
        guard let remaining else { return Color.primary }
        if remaining <= 5 { return critical }
        if remaining <= 10 { return warning }
        if remaining <= 20 { return caution }
        return healthy
    }

    static let accentTint = accent
}
