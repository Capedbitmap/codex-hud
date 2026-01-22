import SwiftUI

struct GlassDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.1))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }
}
