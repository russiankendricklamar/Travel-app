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
        VStack(spacing: AppTheme.spacingM) {
            countdownHero
            flightInfoCard
        }
    }

    // MARK: - Countdown Hero

    private var countdownHero: some View {
        VStack(spacing: AppTheme.spacingM) {
            Spacer(minLength: 20)

            Text("ВЫЛЕТ ЧЕРЕЗ")
                .font(.system(size: 11, weight: .bold))
                .tracking(5)
                .foregroundStyle(AppTheme.sakuraPink)

            Text("\(countdownDays)")
                .font(.system(size: 120, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .shadow(color: AppTheme.sakuraPink.opacity(0.3), radius: 20, x: 0, y: 10)
                .contentTransition(.numericText())
                .animation(.default, value: countdownDays)

            HStack(spacing: 8) {
                Capsule()
                    .fill(AppTheme.sakuraPink.opacity(0.3))
                    .frame(height: 1.5)
                Text(daysWord(countdownDays))
                    .font(.system(size: 13, weight: .bold))
                    .tracking(4)
                    .foregroundStyle(AppTheme.sakuraPink)
                    .fixedSize()
                Capsule()
                    .fill(AppTheme.sakuraPink.opacity(0.3))
                    .frame(height: 1.5)
            }
            .padding(.horizontal, AppTheme.spacingL)

            HStack(spacing: 8) {
                countdownUnit(value: countdownHours, label: "ЧАС")
                countdownSeparator
                countdownUnit(value: countdownMinutes, label: "МИН")
                countdownSeparator
                countdownUnit(value: countdownSeconds, label: "СЕК")
            }
            .padding(.top, 4)

            Spacer(minLength: 20)
        }
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusXL))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusXL)
                .strokeBorder(
                    LinearGradient(
                        colors: [AppTheme.sakuraPink.opacity(0.5), AppTheme.sakuraPink.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: AppTheme.sakuraPink.opacity(0.15), radius: 20, x: 0, y: 10)
        .padding(.top, 8)
        .scaleEffect(heroScale)
    }

    private func countdownUnit(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text(String(format: "%02d", value))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .animation(.default, value: value)
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(.secondary)
        }
        .frame(width: 70)
        .padding(.vertical, 10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
    }

    private var countdownSeparator: some View {
        Text(":")
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .foregroundStyle(AppTheme.sakuraPink.opacity(0.4))
    }

    private func daysWord(_ count: Int) -> String {
        let mod10 = count % 10
        let mod100 = count % 100
        if mod100 >= 11 && mod100 <= 19 { return "ДНЕЙ" }
        if mod10 == 1 { return "ДЕНЬ" }
        if mod10 >= 2 && mod10 <= 4 { return "ДНЯ" }
        return "ДНЕЙ"
    }

    // MARK: - Flight Info

    private var flightInfoCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "airplane.departure")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(
                    LinearGradient(
                        colors: [AppTheme.sakuraPink, AppTheme.sakuraPink.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))

            VStack(alignment: .leading, spacing: 2) {
                Text(trip.name.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.primary)
                Text(tripDateRange.uppercased())
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("РЕЙС")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(.tertiary)
                if let flight = trip.flightDate {
                    Text(flightDateFormatted(flight))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.sakuraPink)
                }
            }
        }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
        .offset(y: statsOffset)
    }

    // MARK: - Helpers

    private var tripDateRange: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM"
        let start = formatter.string(from: trip.startDate)
        let end = formatter.string(from: trip.endDate)
        return "\(start) – \(end) // \(trip.totalDays) дн."
    }

    private func flightDateFormatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMM, HH:mm"
        return f.string(from: date)
    }
}
