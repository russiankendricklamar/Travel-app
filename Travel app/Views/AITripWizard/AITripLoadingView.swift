import SwiftUI

struct AITripLoadingView: View {
    let phase: String

    @State private var rotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: AppTheme.spacingXL) {
            Spacer()

            ZStack {
                // Pulse ring
                Circle()
                    .stroke(AppTheme.sakuraPink.opacity(0.2), lineWidth: 2)
                    .frame(width: 120, height: 120)
                    .scaleEffect(pulseScale)
                    .opacity(2.0 - Double(pulseScale))

                // Rotating airplane
                Image(systemName: "airplane")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(AppTheme.sakuraPink)
                    .rotationEffect(.degrees(rotation))
            }

            // Phase text card
            VStack(spacing: 12) {
                Text(phase)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())

                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(AppTheme.sakuraPink)
                            .frame(width: 6, height: 6)
                            .opacity(dotOpacity(for: index))
                    }
                }
            }
            .padding(AppTheme.spacingL)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                    .stroke(AppTheme.sakuraPink.opacity(0.15), lineWidth: 0.5)
            )

            Text("AI планирует ваше путешествие")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(AppTheme.spacingM)
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.4
            }
        }
    }

    private func dotOpacity(for index: Int) -> Double {
        let phaseIndex: Int
        if phase.contains("маршрут") { phaseIndex = 0 }
        else if phase.contains("билет") { phaseIndex = 1 }
        else { phaseIndex = 2 }

        return index <= phaseIndex ? 1.0 : 0.3
    }
}
