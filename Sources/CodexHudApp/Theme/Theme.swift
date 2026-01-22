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

    static let readyGradient = LinearGradient(
        colors: [PremiumColors.accent, PremiumColors.accentLight],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let warningGradient = LinearGradient(
        colors: [PremiumColors.warning, PremiumColors.warningLight],
        startPoint: .top,
        endPoint: .bottom
    )

    static let criticalGradient = LinearGradient(
        colors: [PremiumColors.critical, PremiumColors.criticalGlow],
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
            return PremiumColors.accentGlow
        case .warning:
            return PremiumColors.warning
        case .critical:
            return PremiumColors.criticalGlow
        }
    }

    static let accentTint = PremiumColors.accent
}
