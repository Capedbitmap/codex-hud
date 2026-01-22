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
    enum Elevation {
        case inset
        case standard
        case raised
    }

    var cornerRadius: CGFloat
    var material: NSVisualEffectView.Material = .hudWindow
    var elevation: Elevation = .standard
    var tint: Color? = nil
    var animateHighlight: Bool = false

    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        ZStack {
            VisualEffectView(material: material)

            shape
                .fill(Color.clear)

            if let tint {
                tint.opacity(0.04).blendMode(.plusLighter)
            }
        }
        .clipShape(shape)
        .overlay(
            ZStack {
                shape.stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                shape.strokeBorder(Theme.glassStroke, lineWidth: 1)
            }
        )
        .onAppear { }
    }
}
