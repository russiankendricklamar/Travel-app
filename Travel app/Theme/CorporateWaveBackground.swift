import SwiftUI

// Corporate mode disabled — this view is not currently used
struct CorporateWaveBackground: View {
    @AppStorage("colorPalette") private var palette: String = ColorPalette.sakura.rawValue

    private var resolvedPalette: ColorPalette {
        ColorPalette(rawValue: palette) ?? .sakura
    }

    private var glowColor: Color {
        resolvedPalette.accentColor
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                // Wave 1 — large, sweeping from bottom-left
                drawWave(
                    context: &context, size: size, time: t,
                    config: WaveConfig(
                        startY: 0.65, endY: 0.30,
                        amplitude: 45, frequency: 0.8, speed: 0.12,
                        phase: 0,
                        fillOpacity: 0.08,
                        glowOpacity: 0.18,
                        glowBlur: 12
                    )
                )

                // Wave 2 — crossing, mid-screen
                drawWave(
                    context: &context, size: size, time: t,
                    config: WaveConfig(
                        startY: 0.75, endY: 0.40,
                        amplitude: 55, frequency: 0.6, speed: -0.09,
                        phase: 2.0,
                        fillOpacity: 0.06,
                        glowOpacity: 0.14,
                        glowBlur: 10
                    )
                )

                // Wave 3 — subtle foreground
                drawWave(
                    context: &context, size: size, time: t,
                    config: WaveConfig(
                        startY: 0.85, endY: 0.55,
                        amplitude: 35, frequency: 1.0, speed: 0.08,
                        phase: 4.2,
                        fillOpacity: 0.05,
                        glowOpacity: 0.10,
                        glowBlur: 8
                    )
                )

                // Wave 4 — deep background, barely visible
                drawWave(
                    context: &context, size: size, time: t,
                    config: WaveConfig(
                        startY: 0.50, endY: 0.20,
                        amplitude: 30, frequency: 0.5, speed: -0.06,
                        phase: 6.0,
                        fillOpacity: 0.04,
                        glowOpacity: 0.08,
                        glowBlur: 14
                    )
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Config

    private struct WaveConfig {
        let startY: CGFloat   // left edge Y (0–1)
        let endY: CGFloat     // right edge Y (0–1) — diagonal tilt
        let amplitude: CGFloat
        let frequency: CGFloat
        let speed: CGFloat
        let phase: Double
        let fillOpacity: Double
        let glowOpacity: Double
        let glowBlur: CGFloat
    }

    // MARK: - Draw

    private func drawWave(
        context: inout GraphicsContext,
        size: CGSize,
        time: Double,
        config c: WaveConfig
    ) {
        let step: CGFloat = 4
        let count = Int(size.width / step) + 1
        let phase = time * c.speed + c.phase

        // Y-axis breathing
        let breath = sin(time * 0.25 + c.phase * 0.5) * 8

        var points: [CGPoint] = []

        for i in 0...count {
            let x = CGFloat(i) * step
            let norm = x / size.width

            // Diagonal baseline: interpolate startY → endY
            let baseY = size.height * (c.startY + (c.endY - c.startY) * norm) + CGFloat(breath)

            // Smooth wave: primary + soft harmonic
            let wave = sin(norm * .pi * 2 * c.frequency + phase) * c.amplitude
                + sin(norm * .pi * 3 * c.frequency + phase * 1.2) * c.amplitude * 0.2

            points.append(CGPoint(x: x, y: baseY + wave))
        }

        guard !points.isEmpty else { return }

        // Crest path
        var crestPath = Path()
        crestPath.move(to: points[0])
        for p in points.dropFirst() { crestPath.addLine(to: p) }

        // Filled body path
        var fillPath = Path()
        fillPath.move(to: points[0])
        for p in points.dropFirst() { fillPath.addLine(to: p) }
        fillPath.addLine(to: CGPoint(x: size.width + 4, y: size.height + 10))
        fillPath.addLine(to: CGPoint(x: -4, y: size.height + 10))
        fillPath.closeSubpath()

        let crestMinY = points.map(\.y).min() ?? size.height * 0.5

        // 1) Fill — dark body, barely visible, uses palette glow at crest
        context.fill(
            fillPath,
            with: .linearGradient(
                Gradient(colors: [
                    glowColor.opacity(c.fillOpacity * 0.6),
                    Color.white.opacity(c.fillOpacity * 0.15),
                    Color.white.opacity(c.fillOpacity * 0.05),
                    Color.clear,
                ]),
                startPoint: CGPoint(x: size.width * 0.5, y: crestMinY),
                endPoint: CGPoint(x: size.width * 0.5, y: crestMinY + c.amplitude * 4)
            )
        )

        // 2) Soft glow on crest
        context.drawLayer { glow in
            glow.addFilter(.blur(radius: c.glowBlur))
            glow.opacity = c.glowOpacity * 0.5
            glow.stroke(
                crestPath,
                with: .color(glowColor),
                style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
            )
        }

        // 3) Tight inner glow
        context.drawLayer { inner in
            inner.addFilter(.blur(radius: c.glowBlur * 0.25))
            inner.opacity = c.glowOpacity * 0.7
            inner.stroke(
                crestPath,
                with: .color(glowColor),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
        }

        // 4) Crisp thin crest line
        context.stroke(
            crestPath,
            with: .color(glowColor.opacity(c.glowOpacity * 0.6)),
            style: StrokeStyle(lineWidth: 0.8, lineCap: .round, lineJoin: .round)
        )
    }
}
