import SwiftUI

enum PremiumColors {
    static let accent = Color(hue: 0.48, saturation: 0.72, brightness: 0.68)
    static let accentLight = Color(hue: 0.48, saturation: 0.55, brightness: 0.85)
    static let accentGlow = Color(hue: 0.48, saturation: 0.8, brightness: 0.95)

    static let warning = Color(hue: 0.08, saturation: 0.78, brightness: 0.92)
    static let warningLight = Color(hue: 0.08, saturation: 0.45, brightness: 0.98)

    static let critical = Color(hue: 0.98, saturation: 0.68, brightness: 0.78)
    static let criticalGlow = Color(hue: 0.98, saturation: 0.55, brightness: 0.95)

    static let surfaceHigh = Color.white.opacity(0.06)
    static let surfaceMid = Color.white.opacity(0.03)
    static let surfaceLow = Color.black.opacity(0.015)
}
