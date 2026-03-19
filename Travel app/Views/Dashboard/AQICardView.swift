import SwiftUI

struct AQICardView: View {
    let aqi: AirQualityInfo

    private let segmentColors: [Color] = [.green, .yellow, .orange, .red, .purple, Color(red: 0.5, green: 0, blue: 0)]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GlassSectionHeader(title: "КАЧЕСТВО ВОЗДУХА", color: aqi.color)

            VStack(alignment: .leading, spacing: 12) {
                // Level + index
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(aqi.epaIndex)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("— \(aqi.levelLocalized)")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(aqi.color)
                }

                // Gradient bar (iOS Weather style)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Gradient background
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: segmentColors,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 6)

                        // Indicator dot
                        let position = CGFloat(aqi.epaIndex - 1) / 5.0
                        Circle()
                            .fill(.white)
                            .frame(width: 12, height: 12)
                            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .offset(x: max(0, min(geo.size.width - 12, geo.size.width * position - 6)))
                    }
                }
                .frame(height: 12)

                // Health advice
                Text(aqi.healthAdvice)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider().opacity(0.1)

                // PM values row
                HStack(spacing: 0) {
                    pmItem(label: "PM2.5", value: aqi.pm25)
                    pmItem(label: "PM10", value: aqi.pm10)
                }
            }
            .padding(.horizontal, AppTheme.spacingM)
            .padding(.bottom, AppTheme.spacingM)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
    }

    private func pmItem(label: String, value: Double) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)
            Text(String(format: "%.1f", value))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text("мкг/м\u{00B3}")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
