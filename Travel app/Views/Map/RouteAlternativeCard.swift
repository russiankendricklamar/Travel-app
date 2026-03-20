import SwiftUI

// MARK: - RouteBadge

enum RouteBadge {
    case fastest
    case shortest

    var label: String {
        switch self {
        case .fastest:  return "Быстрый"
        case .shortest: return "Короткий"
        }
    }
}

// MARK: - RouteAlternativeCard

struct RouteAlternativeCard: View {
    let route: RouteResult
    let isSelected: Bool
    let badge: RouteBadge?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                // Row 1: transport icon + badge
                HStack {
                    Image(systemName: route.mode.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(route.mode.color)
                    Spacer()
                    if let badge {
                        Text(badge.label)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppTheme.sakuraPink)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 4)
                            .background(AppTheme.sakuraPink.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }

                // Row 2: ETA hero
                Text(RoutingService.formatDuration(route.expectedTravelTime))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(route.mode.color)

                // Row 3: distance or transfer count
                Text(distanceOrTransfers)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(AppTheme.spacingM)
            .frame(width: 140, height: 88)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .stroke(
                        isSelected ? AppTheme.sakuraPink : Color.white.opacity(0.12),
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
            .shadow(
                color: isSelected ? AppTheme.sakuraPink.opacity(0.12) : .black.opacity(0.06),
                radius: isSelected ? 12 : 8
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.85), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Computed Properties

    private var distanceOrTransfers: String {
        if route.mode == .transit {
            return transfersLabel(transferCount)
        }
        return RoutingService.formatDistance(route.distance)
    }

    private var transferCount: Int {
        route.transitSteps.filter { $0.travelMode == "TRANSIT" }.count
    }

    private var accessibilityText: String {
        var parts = ["Маршрут"]
        parts.append(RoutingService.formatDuration(route.expectedTravelTime))
        parts.append(route.mode == .transit ? transfersLabel(transferCount) : RoutingService.formatDistance(route.distance))
        if let badge { parts.append(badge.label) }
        return parts.joined(separator: ", ")
    }

    // MARK: - Russian Declension

    private func transfersLabel(_ count: Int) -> String {
        let rem10 = count % 10
        let rem100 = count % 100
        if rem100 >= 11 && rem100 <= 14 { return "\(count) пересадок" }
        switch rem10 {
        case 1:       return "\(count) пересадка"
        case 2, 3, 4: return "\(count) пересадки"
        default:      return "\(count) пересадок"
        }
    }
}

// MARK: - RouteAlternativeCardSkeleton

struct RouteAlternativeCardSkeleton: View {
    @State private var opacity: Double = 0.4

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
            // ETA slot
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.12))
                .frame(width: 40, height: 20)

            // Distance slot
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.12))
                .frame(width: 60, height: 13)
        }
        .padding(AppTheme.spacingM)
        .frame(width: 140, height: 88)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                opacity = 1.0
            }
        }
    }
}
