import SwiftUI

struct IconButton: View {
    let icon: String
    let help: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isHovering ? Color.primary : Theme.secondary)
                .padding(8)
                .background(
                    GlassSurface(
                        cornerRadius: 12,
                        material: .hudWindow,
                        elevation: isHovering ? .raised : .inset,
                        tint: nil,
                        animateHighlight: false
                    )
                )
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hovering in
            withAnimation(AppAnimations.snappy) {
                isHovering = hovering
            }
        }
    }
}
