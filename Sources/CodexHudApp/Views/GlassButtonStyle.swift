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
                    highlightOpacity: configuration.isPressed ? 0.15 : 0.25,
                    strokeOpacity: 0.4
                )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}
