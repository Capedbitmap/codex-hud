import SwiftUI

struct GlassCard<Content: View>: View {
    let content: Content
    @State private var isHovering = false

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        return content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                GlassSurface(cornerRadius: 18, material: .hudWindow, elevation: .standard, tint: nil, animateHighlight: false)
            )
            .shadow(color: Theme.glassShadow, radius: 14, x: 0, y: 8)
            .scaleEffect(isHovering ? 1.01 : 1.0)
            .onHover { hovering in
                withAnimation(AppAnimations.snappy) {
                    isHovering = hovering
                }
            }
    }
}
