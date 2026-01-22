import SwiftUI
import CodexHudCore

enum Theme {
    static let background = LinearGradient(
        colors: [Color.white.opacity(0.18), Color.clear],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let glassStroke = LinearGradient(
        colors: [Color.white.opacity(0.65), Color.white.opacity(0.05)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let glassShadow = Color.black.opacity(0.18)
    static let muted = Color.secondary.opacity(0.7)
    static let secondary = Color.secondary

    static let readyGradient = LinearGradient(
        colors: [Color.mint, Color.teal],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let warningGradient = LinearGradient(
        colors: [Color.orange, Color.yellow],
        startPoint: .top,
        endPoint: .bottom
    )

    static let criticalGradient = LinearGradient(
        colors: [Color.red, Color.pink],
        startPoint: .top,
        endPoint: .bottom
    )

    static func gradient(for level: ThresholdLevel) -> LinearGradient {
        switch level {
        case .normal:
            return readyGradient
        case .warning:
            return warningGradient
        case .critical:
            return criticalGradient
        }
    }

    static func glow(for level: ThresholdLevel) -> Color {
        switch level {
        case .normal:
            return Color.mint
        case .warning:
            return Color.orange
        case .critical:
            return Color.red
        }
    }
}
