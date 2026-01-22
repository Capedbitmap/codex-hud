import AppKit
import SwiftUI

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blending: NSVisualEffectView.BlendingMode = .behindWindow
    var state: NSVisualEffectView.State = .active

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blending
        view.state = state
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blending
        nsView.state = state
    }
}

struct GlassSurface: View {
    var cornerRadius: CGFloat
    var material: NSVisualEffectView.Material
    var highlightOpacity: Double = 0.35
    var strokeOpacity: Double = 0.5

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        ZStack {
            VisualEffectView(material: material)

            LinearGradient(
                colors: [Color.white.opacity(0.12), Color.clear, Color.black.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.35)

            GlassHighlight()
                .opacity(highlightOpacity)
                .blendMode(.screen)
        }
        .clipShape(shape)
        .overlay(
            shape.stroke(Theme.glassStroke, lineWidth: 1)
                .opacity(strokeOpacity)
        )
    }
}

private struct GlassHighlight: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                RadialGradient(
                    colors: [Color.white.opacity(0.4), Color.clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: max(size.width, size.height) * 0.6
                )
                .offset(x: -size.width * 0.15, y: -size.height * 0.2)

                LinearGradient(
                    colors: [Color.white.opacity(0.25), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: size.height * 0.25)
                .offset(y: -size.height * 0.35)
            }
        }
    }
}
