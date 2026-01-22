import SwiftUI

enum Typography {
    static let heroLarge = Font.system(size: 46, weight: .semibold, design: .default)
    static let heroMedium = Font.system(size: 32, weight: .semibold, design: .default)

    static let cardTitle = Font.system(size: 13, weight: .semibold, design: .default)
    static let cardValue = Font.system(size: 20, weight: .semibold, design: .default)
    static let metric = Font.system(size: 32, weight: .semibold, design: .default)

    static let label = Font.system(size: 12, weight: .medium, design: .default)
    static let meta = Font.system(size: 11, weight: .medium, design: .monospaced)
    static let caption = Font.system(size: 10, weight: .medium, design: .default)

    static let button = Font.system(size: 12, weight: .semibold, design: .default)
    static let chip = Font.system(size: 11, weight: .semibold, design: .default)
}
