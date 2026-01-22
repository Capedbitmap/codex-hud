import SwiftUI
import CodexHudCore

struct PremiumCircularGauge: View {
    let progress: Double
    let level: ThresholdLevel

    @State private var animatedProgress: Double = 0
    @State private var glowOpacity: Double = 0.25

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 10)
                .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: gradientColors),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            if level != .normal {
                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(glowColor, lineWidth: 10)
                    .blur(radius: 8)
                    .opacity(glowOpacity)
                    .rotationEffect(.degrees(-90))
            }

            VStack(spacing: 2) {
                Text("\(Int(progress))")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.gradient(for: level))
                Text("%")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.secondary)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) {
                animatedProgress = progress / 100
            }
            if level != .normal {
                withAnimation(AppAnimations.breathe) {
                    glowOpacity = 0.6
                }
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.85)) {
                animatedProgress = newValue / 100
            }
        }
    }

    private var gradientColors: [Color] {
        switch level {
        case .normal:
            return [PremiumColors.accentLight, PremiumColors.accent, PremiumColors.accentGlow]
        case .warning:
            return [PremiumColors.warningLight, PremiumColors.warning]
        case .critical:
            return [PremiumColors.criticalGlow, PremiumColors.critical]
        }
    }

    private var glowColor: Color {
        Theme.glow(for: level)
    }
}
