import SwiftUI

struct GlassCard<Content: View>: View {
    let content: Content
    @State private var isHovering = false

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        return content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                shape
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                shape
                    .fill(Theme.background)
                    .opacity(0.35)
            )
            .overlay(
                shape
                    .stroke(Theme.glassStroke, lineWidth: 1)
            )
            .shadow(color: Theme.glassShadow, radius: 10, x: 0, y: 6)
            .scaleEffect(isHovering ? 1.01 : 1.0)
            .onHover { hovering in
                withAnimation(.snappy(duration: 0.2)) {
                    isHovering = hovering
                }
            }
    }
}
