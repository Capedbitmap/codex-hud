import SwiftUI

enum AppAnimations {
    static let bouncy = Animation.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0)
    static let snappy = Animation.spring(response: 0.25, dampingFraction: 0.85, blendDuration: 0)
    static let smooth = Animation.spring(response: 0.5, dampingFraction: 0.9, blendDuration: 0)

    static let stateChange = Animation.easeOut(duration: 0.2)
    static let emphasis = Animation.easeInOut(duration: 0.35)

    static let breathe = Animation.easeInOut(duration: 3).repeatForever(autoreverses: true)
    static let pulse = Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)
}
