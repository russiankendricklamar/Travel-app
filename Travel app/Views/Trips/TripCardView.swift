import SwiftUI

struct TripCardView: View {
    let trip: Trip

    var body: some View {
        HStack(spacing: AppTheme.spacingS) {
            Image(systemName: trip.coverSystemImage)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(
                    LinearGradient(
                        colors: [phaseColor, phaseColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(trip.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer()
                    phaseBadge
                }

                Text(trip.destination)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(dateRange)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)

                if trip.isActive {
                    progressBar
                }
            }
        }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .strokeBorder(
                    LinearGradient(
                        colors: [phaseColor.opacity(0.4), phaseColor.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: phaseColor.opacity(0.1), radius: 12, x: 0, y: 6)
    }

    // MARK: - Phase Badge

    private var phaseBadge: some View {
        Text(phaseLabel)
            .font(.system(size: 8, weight: .bold))
            .tracking(1)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(phaseColor)
            .clipShape(Capsule())
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(phaseColor.opacity(0.15))
                    .frame(height: 4)
                Capsule()
                    .fill(phaseColor)
                    .frame(width: geo.size.width * trip.progress, height: 4)
            }
        }
        .frame(height: 4)
        .padding(.top, 2)
    }

    // MARK: - Helpers

    private var phaseLabel: String {
        switch trip.phase {
        case .preTrip: return "СКОРО"
        case .active: return "СЕЙЧАС"
        case .postTrip: return "АРХИВ"
        }
    }

    private var phaseColor: Color {
        switch trip.phase {
        case .preTrip: return AppTheme.oceanBlue
        case .active: return AppTheme.bambooGreen
        case .postTrip: return AppTheme.textSecondary
        }
    }

    private var dateRange: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM yyyy"
        return "\(formatter.string(from: trip.startDate)) - \(formatter.string(from: trip.endDate))"
    }
}
