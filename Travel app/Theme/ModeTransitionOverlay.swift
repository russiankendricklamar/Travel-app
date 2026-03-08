import SwiftUI

struct ModeTransitionOverlay: View {
    let targetMode: AppMode
    let onComplete: () -> Void

    // Waves
    @State private var wave1X: CGFloat = 0
    @State private var wave2X: CGFloat = 0
    @State private var wave3X: CGFloat = 0

    // Pulse rings
    @State private var ringScale: CGFloat = 0.2
    @State private var ringOpacity: CGFloat = 0.6
    @State private var ring2Scale: CGFloat = 0.1
    @State private var ring2Opacity: CGFloat = 0.4

    // Icon
    @State private var iconScale: CGFloat = 0.0
    @State private var iconOpacity: CGFloat = 0.0

    // Fade
    @State private var fadeOut: CGFloat = 1.0

    private var isCorp: Bool { targetMode == .corporate }

    private var bgColor: Color {
        isCorp ? Color(hex: "050810") : personalBg
    }
    private var accentColor: Color {
        isCorp ? CorporateColors.electricBlue : personalPalette.accentColor
    }
    private var personalPalette: ColorPalette {
        ColorPalette(rawValue: UserDefaults.standard.string(forKey: "savedPersonalPalette") ?? "sakura") ?? .sakura
    }
    private var personalBg: Color {
        personalPalette.backgroundColors.first ?? Color(hex: "FFF5F8")
    }

    var body: some View {
        ZStack {
            // Base dim
            Color.black.ignoresSafeArea()

            // Wave 3 — back
            waveView(
                color: isCorp ? Color(hex: "090E1A") : personalPalette.backgroundColors.last ?? personalBg,
                offsetX: wave3X
            )

            // Wave 2 — middle
            waveView(
                color: isCorp ? Color(hex: "070B14") : personalBg.opacity(0.8),
                offsetX: wave2X
            )

            // Wave 1 — front
            waveView(
                color: bgColor,
                offsetX: wave1X
            )

            // Pulse rings
            Circle()
                .stroke(accentColor.opacity(ringOpacity), lineWidth: 2)
                .frame(width: 200, height: 200)
                .scaleEffect(ringScale)

            Circle()
                .stroke(accentColor.opacity(ring2Opacity), lineWidth: 1.5)
                .frame(width: 200, height: 200)
                .scaleEffect(ring2Scale)

            // Center icon
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 72, height: 72)

                    Image(systemName: targetMode.icon)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(accentColor)
                }

                Text(targetMode.label)
                    .font(.system(size: 14, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(isCorp ? CorporateColors.silver : .white)
            }
            .scaleEffect(iconScale)
            .opacity(iconOpacity)
        }
        .opacity(fadeOut)
        .ignoresSafeArea()
        .onAppear {
            runAnimation()
        }
    }

    private func waveView(color: Color, offsetX: CGFloat) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: UIScreen.main.bounds.width + 80)
            .ignoresSafeArea()
            .offset(x: offsetX)
    }

    private func runAnimation() {
        let screenW = UIScreen.main.bounds.width
        let startX = -(screenW + 80)

        wave1X = startX
        wave2X = startX
        wave3X = startX

        withAnimation(.easeOut(duration: 0.55)) {
            wave3X = 0
        }
        withAnimation(.easeOut(duration: 0.55).delay(0.07)) {
            wave2X = 0
        }
        withAnimation(.easeOut(duration: 0.55).delay(0.14)) {
            wave1X = 0
        }
        withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
            ringScale = 2.5
            ringOpacity = 0
        }
        withAnimation(.easeOut(duration: 0.7).delay(0.45)) {
            ring2Scale = 2.0
            ring2Opacity = 0
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.6).delay(0.4)) {
            iconScale = 1.0
            iconOpacity = 1.0
        }
        withAnimation(.easeIn(duration: 0.3).delay(1.1)) {
            fadeOut = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) {
            onComplete()
        }
    }
}
