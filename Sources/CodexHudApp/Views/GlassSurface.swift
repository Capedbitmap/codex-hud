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
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.24 : 0.08), radius: 1, x: 0, y: 1)

            LinearGradient(
                stops: [
                    .init(color: PremiumColors.surfaceHigh, location: 0),
                    .init(color: PremiumColors.surfaceMid, location: 0.35),
                    .init(color: PremiumColors.surfaceLow, location: 1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if let tint {
                tint.opacity(0.08).blendMode(.plusLighter)
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
