import SwiftUI

struct HeroTripCard: View {
    let trip: Trip
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Top row: icon + info + badge
                HStack(spacing: AppTheme.spacingS) {
                    Image(systemName: trip.coverSystemImage)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(
                            LinearGradient(
                                colors: [phaseColor, phaseColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(trip.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text(trip.flaggedCountriesDisplay)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    phaseBadge
                }
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.top, AppTheme.spacingM)

                // Dates row
                HStack {
                    Text(dateRange)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.top, AppTheme.spacingS)

                // Progress or countdown
                if trip.isActive {
                    progressSection
                } else if trip.isUpcoming {
                    countdownSection
                }

                Spacer().frame(height: AppTheme.spacingM)
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusXL))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusXL)
                    .strokeBorder(
                        LinearGradient(
                            colors: [phaseColor.opacity(0.4), phaseColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: phaseColor.opacity(0.15), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Phase Badge

    private var phaseBadge: some View {
        Text(phaseLabel)
            .font(.system(size: 9, weight: .bold))
            .tracking(1)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(phaseColor)
            .clipShape(Capsule())
    }

    // MARK: - Progress (active trip)

    private var progressSection: some View {
        VStack(spacing: 6) {
            Rectangle()
                .fill(phaseColor.opacity(0.12))
                .frame(height: 0.5)
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.top, AppTheme.spacingS)

            HStack {
                Text("ДЕНЬ \(trip.currentDay) ИЗ \(trip.totalDays)")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(phaseColor)
                Spacer()
                Text("\(Int(trip.progress * 100))%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(phaseColor)
            }
            .padding(.horizontal, AppTheme.spacingM)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(phaseColor.opacity(0.15))
                        .frame(height: 6)
                    Capsule()
                        .fill(phaseColor)
                        .frame(width: geo.size.width * trip.progress, height: 6)
                }
            }
            .frame(height: 6)
            .padding(.horizontal, AppTheme.spacingM)
        }
    }

    // MARK: - Countdown (upcoming trip)

    private var countdownSection: some View {
        VStack(spacing: 6) {
            Rectangle()
                .fill(phaseColor.opacity(0.12))
                .frame(height: 0.5)
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.top, AppTheme.spacingS)

            HStack {
                Text("ДО ПОЕЗДКИ")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(phaseColor)
                Spacer()
                Text("\(daysUntilStart) \(daysWord(daysUntilStart))")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(phaseColor)
            }
            .padding(.horizontal, AppTheme.spacingM)
        }
    }

    // MARK: - Helpers

    private var phaseLabel: String {
        switch trip.phase {
        case .preTrip: return String(localized: "СКОРО")
        case .active: return String(localized: "СЕЙЧАС")
        case .postTrip: return String(localized: "ЗАВЕРШЕНА")
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
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "d MMM yyyy"
        return "\(f.string(from: trip.startDate)) – \(f.string(from: trip.endDate))"
    }

    private var daysUntilStart: Int {
        max(0, Calendar.current.dateComponents([.day], from: Date(), to: trip.startDate).day ?? 0)
    }

    private func daysWord(_ count: Int) -> String {
        let mod10 = count % 10
        let mod100 = count % 100
        if mod100 >= 11 && mod100 <= 19 { return "дней" }
        if mod10 == 1 { return "день" }
        if mod10 >= 2 && mod10 <= 4 { return "дня" }
        return "дней"
    }
}
