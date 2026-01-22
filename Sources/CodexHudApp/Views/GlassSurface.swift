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
    @State private var highlightPhase: CGFloat = 0

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        ZStack {
            VisualEffectView(material: material)

            shape
                .fill(Color.clear)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.24 : 0.08), radius: 1, x: 0, y: 1)

            GlassEdgeHighlight(phase: animateHighlight ? highlightPhase : 0.5)
                .opacity(0.25)
                .blendMode(.screen)

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
        .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowOffsetY)
        .onAppear {
            guard animateHighlight else { return }
            withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                highlightPhase = 1
            }
        }
    }

    private var shadowColor: Color {
        switch elevation {
        case .inset:
            return Color.black.opacity(0.1)
        case .standard:
            return Color.black.opacity(0.18)
        case .raised:
            return Color.black.opacity(0.28)
        }
    }

    private var shadowRadius: CGFloat {
        switch elevation {
        case .inset:
            return 6
        case .standard:
            return 12
        case .raised:
            return 18
        }
    }

    private var shadowOffsetY: CGFloat {
        switch elevation {
        case .inset:
            return 2
        case .standard:
            return 6
        case .raised:
            return 10
        }
    }
}

private struct GlassEdgeHighlight: View {
    var phase: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let xOffset = (phase - 0.5) * size.width * 0.4

            LinearGradient(
                colors: [Color.white.opacity(0.45), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: size.width * 0.8, height: size.height * 0.6)
            .offset(x: xOffset, y: -size.height * 0.2)
        }
    }
}
