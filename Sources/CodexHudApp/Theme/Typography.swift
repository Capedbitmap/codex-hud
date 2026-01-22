import SwiftUI

enum Typography {
    static let heroLarge = Font.system(size: 46, weight: .bold, design: .rounded)
    static let heroMedium = Font.system(size: 32, weight: .bold, design: .rounded)

    static let cardTitle = Font.system(size: 13, weight: .semibold, design: .rounded)
    static let cardValue = Font.system(size: 22, weight: .bold, design: .rounded)

    static let label = Font.system(size: 12, weight: .medium, design: .rounded)
    static let meta = Font.system(size: 11, weight: .medium, design: .monospaced)
    static let caption = Font.system(size: 10, weight: .medium, design: .rounded)

    static let button = Font.system(size: 12, weight: .semibold, design: .rounded)
    static let chip = Font.system(size: 11, weight: .semibold, design: .rounded)
}
