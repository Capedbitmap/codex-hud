import SwiftUI

enum Theme {
    static let background = LinearGradient(
        colors: [Color(red: 0.94, green: 0.96, blue: 0.98), Color(red: 0.84, green: 0.88, blue: 0.94)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accent = Color(red: 0.20, green: 0.45, blue: 0.85)
    static let warning = Color(red: 0.90, green: 0.55, blue: 0.20)
    static let critical = Color(red: 0.85, green: 0.20, blue: 0.20)
    static let muted = Color(red: 0.45, green: 0.50, blue: 0.58)
}
