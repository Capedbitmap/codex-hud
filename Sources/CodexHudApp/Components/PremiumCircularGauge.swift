import SwiftUI
import CodexHudCore

struct PremiumCircularGauge: View {
    let progress: Double
    let tint: Color

    @State private var animatedProgress: Double = 0
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 10)
                .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text("\(Int(progress))")
                    .font(Typography.metric)
                    .monospacedDigit()
                    .foregroundStyle(tint)
                Text("%")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.secondary)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) {
                animatedProgress = progress / 100
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.85)) {
                animatedProgress = newValue / 100
            }
        }
    }
}
