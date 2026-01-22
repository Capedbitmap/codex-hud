import SwiftUI

struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                GlassSurface(
                    cornerRadius: 10,
                    material: .hudWindow,
                    elevation: configuration.isPressed ? .inset : .raised,
                    tint: nil,
                    animateHighlight: false
                )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}
