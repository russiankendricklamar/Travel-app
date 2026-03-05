import SwiftUI

struct DashboardCountdownSection: View {
    let trip: Trip
    let heroScale: CGFloat
    let countdownDays: Int
    let countdownHours: Int
    let countdownMinutes: Int
    let countdownSeconds: Int
    let statsOffset: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            // Countdown row
            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text("ВЫЛЕТ ЧЕРЕЗ")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(AppTheme.sakuraPink.opacity(0.7))

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(countdownDays)")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .contentTransition(.numericText())
                            .animation(.default, value: countdownDays)

                        Text(daysWord(countdownDays))
                            .font(.system(size: 11, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(AppTheme.sakuraPink)
                    }
                }

                Spacer()

                // HH:MM:SS compact
                HStack(spacing: 4) {
                    compactUnit(value: countdownHours, label: "ЧАС")
                    Text(":")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.sakuraPink.opacity(0.3))
                    compactUnit(value: countdownMinutes, label: "МИН")
                    Text(":")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.sakuraPink.opacity(0.3))
                    compactUnit(value: countdownSeconds, label: "СЕК")
                }
            }
            .padding(.horizontal, AppTheme.spacingM)
            .padding(.vertical, AppTheme.spacingM)

            // Divider
            Rectangle()
                .fill(AppTheme.sakuraPink.opacity(0.15))
                .frame(height: 0.5)
                .padding(.horizontal, AppTheme.spacingM)

            // Flight info row
            HStack(spacing: 10) {
                Image(systemName: "airplane.departure")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.sakuraPink, AppTheme.sakuraPink.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))

                VStack(alignment: .leading, spacing: 1) {
                    Text(flightDestination.uppercased())
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.primary)
                    Text(tripDateRange.uppercased())
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let flight = trip.flightDate {
                    Text(flightDateFormatted(flight))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.sakuraPink)
                }
            }
            .padding(.horizontal, AppTheme.spacingM)
            .padding(.vertical, 12)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusXL))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusXL)
                .strokeBorder(
                    LinearGradient(
                        colors: [AppTheme.sakuraPink.opacity(0.4), AppTheme.sakuraPink.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: AppTheme.sakuraPink.opacity(0.1), radius: 12, x: 0, y: 6)
        .padding(.top, 8)
        .scaleEffect(heroScale)
        .offset(y: statsOffset)
    }

    // MARK: - Compact Unit

    private func compactUnit(value: Int, label: LocalizedStringKey) -> some View {
        VStack(spacing: 2) {
            Text(String(format: "%02d", value))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .animation(.default, value: value)
            Text(label)
                .font(.system(size: 7, weight: .bold))
                .tracking(1)
                .foregroundStyle(.tertiary)
        }
        .frame(width: 40)
        .padding(.vertical, 6)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
    }

    // MARK: - Helpers

    private func daysWord(_ count: Int) -> String {
        let mod10 = count % 10
        let mod100 = count % 100
        if mod100 >= 11 && mod100 <= 19 { return String(localized: "ДНЕЙ") }
        if mod10 == 1 { return String(localized: "ДЕНЬ") }
        if mod10 >= 2 && mod10 <= 4 { return String(localized: "ДНЯ") }
        return String(localized: "ДНЕЙ")
    }

    private var flightDestination: String {
        trip.days
            .sorted { $0.date < $1.date }
            .first?.cityName ?? trip.destination
    }

    private var tripDateRange: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "d MMM"
        let start = formatter.string(from: trip.startDate)
        let end = formatter.string(from: trip.endDate)
        return "\(start) – \(end) // \(trip.totalDays) дн."
    }

    private func flightDateFormatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "d MMM, HH:mm"
        return f.string(from: date)
    }
}
