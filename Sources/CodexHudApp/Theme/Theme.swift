import SwiftUI
import CodexHudCore

enum Theme {
    static let glassStroke = LinearGradient(
        colors: [Color.white.opacity(0.65), Color.white.opacity(0.08)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let glassShadow = Color.black.opacity(0.2)
    static let muted = Color.primary.opacity(0.5)
    static let secondary = Color.primary.opacity(0.65)

    static let accent = Color(red: 0.42, green: 0.48, blue: 0.55)
    static let warning = Color(red: 0.78, green: 0.55, blue: 0.2)
    static let critical = Color(red: 0.78, green: 0.33, blue: 0.36)

    static func color(for level: ThresholdLevel) -> Color {
        switch level {
        case .normal:
            return accent
        case .warning:
            return warning
        case .critical:
            return critical
        }
    }

    static let accentTint = accent
}
