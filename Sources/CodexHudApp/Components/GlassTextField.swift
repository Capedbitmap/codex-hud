import SwiftUI

struct GlassTextField: View {
    let placeholder: String
    @Binding var text: String

    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(Typography.label)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                GlassSurface(
                    cornerRadius: 10,
                    material: .hudWindow,
                    elevation: isFocused ? .raised : .inset,
                    tint: isFocused ? Theme.accentTint : nil,
                    animateHighlight: false
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isFocused ? Theme.accent : Color.clear, lineWidth: 1)
            )
            .focused($isFocused)
    }
}
