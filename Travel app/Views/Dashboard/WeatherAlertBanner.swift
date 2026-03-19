import SwiftUI

struct WeatherAlertBanner: View {
    let alerts: [WeatherAPIAlert]

    @State private var expandedAlertID: String?

    var body: some View {
        VStack(spacing: AppTheme.spacingS) {
            ForEach(alerts) { alert in
                alertCard(alert)
            }
        }
    }

    private func alertCard(_ alert: WeatherAPIAlert) -> some View {
        let isExpanded = expandedAlertID == alert.id

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    expandedAlertID = isExpanded ? nil : alert.id
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: alert.isSevere ? "exclamationmark.triangle.fill" : "info.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(alert.severityColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(alert.event ?? alert.headline ?? "Погодное предупреждение")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        if let severity = alert.severity {
                            Text(severityLocalized(severity))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(alert.severityColor)
                        }
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(AppTheme.spacingM)
            }
            .buttonStyle(.plain)

            if isExpanded, let desc = alert.desc, !desc.isEmpty {
                Divider().opacity(0.15).padding(.horizontal, AppTheme.spacingM)

                Text(desc)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(AppTheme.spacingM)

                if let expires = alert.expires {
                    Text("Действует до: \(expires)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, AppTheme.spacingM)
                        .padding(.bottom, AppTheme.spacingS)
                }
            }
        }
        .background(alert.severityColor.opacity(0.08))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(alert.severityColor.opacity(0.3), lineWidth: 1)
        )
    }

    private func severityLocalized(_ severity: String) -> String {
        switch severity.lowercased() {
        case let s where s.contains("extreme"): return "Экстремальная опасность"
        case let s where s.contains("severe"): return "Серьёзная опасность"
        case let s where s.contains("moderate"): return "Умеренная опасность"
        case let s where s.contains("minor"): return "Незначительная опасность"
        default: return severity
        }
    }
}
