import SwiftUI
import CoreLocation

struct DashboardActiveSection: View {
    let trip: Trip
    let heroScale: CGFloat
    let statsOffset: CGFloat
    let counterValue: Int

    @State private var homeTimeZone: TimeZone?
    @State private var destinationTimeZone: TimeZone?
    @State private var currentTime = Date()
    @State private var timer: Timer?

    private let profileService = ProfileService.shared

    private var homeCity: String {
        profileService.profile?.homeCity ?? ""
    }

    private var destinationCity: String {
        let sortedDays = trip.days.sorted { $0.date < $1.date }
        if let today = sortedDays.first(where: { Calendar.current.isDateInToday($0.date) }) {
            return today.cityName
        }
        return sortedDays.first?.cityName ?? ""
    }

    var body: some View {
        VStack(spacing: AppTheme.spacingM) {
            compactHero
            statsBanner
        }
        .task { await resolveTimeZones() }
        .onAppear { startTimer() }
        .onDisappear { timer?.invalidate() }
    }

    // MARK: - Compact Hero with Timezone

    private var compactHero: some View {
        VStack(spacing: 0) {
            // Day counter
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text("\(counterValue)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                VStack(alignment: .leading, spacing: 1) {
                    Text("ДЕНЬ")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(AppTheme.sakuraPink)
                    Text("ПУТЕШЕСТВИЯ")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(AppTheme.sakuraPink.opacity(0.6))
                }
            }
            .padding(.top, AppTheme.spacingS)

            VStack(spacing: 2) {
                Text(trip.name.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(.secondary)
                Text(tripDateRange.uppercased())
                    .font(.system(size: 9, weight: .medium))
                    .tracking(1)
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 4)

            // Timezone comparison (if both cities available)
            if !homeCity.isEmpty && !destinationCity.isEmpty {
                Rectangle()
                    .fill(AppTheme.sakuraPink.opacity(0.15))
                    .frame(height: 0.5)
                    .padding(.horizontal, AppTheme.spacingM)
                    .padding(.top, 12)

                timezoneRow
                    .padding(.horizontal, AppTheme.spacingM)
                    .padding(.vertical, 10)
            } else {
                Spacer().frame(height: AppTheme.spacingM)
            }
        }
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusXL))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusXL)
                .strokeBorder(
                    LinearGradient(
                        colors: [AppTheme.sakuraPink.opacity(0.4), AppTheme.sakuraPink.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: AppTheme.sakuraPink.opacity(0.12), radius: 20, x: 0, y: 10)
        .scaleEffect(heroScale)
    }

    // MARK: - Timezone Row

    private var timezoneRow: some View {
        HStack(spacing: 0) {
            // Home
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(AppTheme.sakuraPink.opacity(0.5))
                    Text(homeCity.uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                Text(formattedTime(in: homeTimeZone ?? .current))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(.default, value: formattedTime(in: homeTimeZone ?? .current))
            }
            .frame(maxWidth: .infinity)

            // Difference badge
            if let diff = timeDifference {
                Text(diff)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.sakuraPink)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(AppTheme.sakuraPink.opacity(0.1))
                    .clipShape(Capsule())
            }

            // Destination
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Text(destinationCity.uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                    Image(systemName: "location.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(AppTheme.sakuraPink.opacity(0.5))
                }
                Text(formattedTime(in: destinationTimeZone ?? .current))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .animation(.default, value: formattedTime(in: destinationTimeZone ?? .current))
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Stats Banner

    private var statsBanner: some View {
        HStack(spacing: 0) {
            bannerStat("\(trip.placesVisitedCount)/\(trip.totalPlacesCount)", label: "МЕСТ", icon: "mappin.and.ellipse")
            Divider().frame(height: 40)
            bannerStat("\(uniqueCities.count)", label: "ГОРОДОВ", icon: "building.2")
            Divider().frame(height: 40)
            bannerStat(CurrencyService.formatBase(trip.totalSpent), label: "ПОТРАЧЕНО", icon: CurrencyService.baseCurrencyIcon)
        }
        .padding(.vertical, AppTheme.spacingM)
        .background(AppTheme.sakuraPink.opacity(0.12))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(AppTheme.sakuraPink.opacity(0.2), lineWidth: 0.5)
        )
        .offset(y: statsOffset)
    }

    private func bannerStat(_ value: String, label: LocalizedStringKey, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(AppTheme.sakuraPink.opacity(0.6))
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.sakuraPink)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .tracking(2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Timezone Helpers

    private func formattedTime(in tz: TimeZone) -> String {
        let f = DateFormatter()
        f.timeZone = tz
        f.dateFormat = "HH:mm"
        return f.string(from: currentTime)
    }

    private var timeDifference: String? {
        guard let home = homeTimeZone, let dest = destinationTimeZone else { return nil }
        let diffSeconds = dest.secondsFromGMT(for: currentTime) - home.secondsFromGMT(for: currentTime)
        let diffHours = diffSeconds / 3600
        let diffMinutes = abs(diffSeconds % 3600) / 60
        if diffHours == 0 && diffMinutes == 0 { return nil }
        let sign = diffHours >= 0 ? "+" : ""
        if diffMinutes == 0 {
            return "\(sign)\(diffHours)ч"
        }
        return "\(sign)\(diffHours):\(String(format: "%02d", diffMinutes))"
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            currentTime = Date()
        }
    }

    private func resolveTimeZones() async {
        async let homeResult = resolveTimeZone(for: homeCity)
        async let destResult = resolveTimeZone(for: destinationCity)
        let (home, dest) = await (homeResult, destResult)
        await MainActor.run {
            homeTimeZone = home
            destinationTimeZone = dest
        }
    }

    private func resolveTimeZone(for city: String) async -> TimeZone? {
        guard !city.isEmpty else { return nil }
        let coder = CLGeocoder()
        return await withCheckedContinuation { continuation in
            coder.geocodeAddressString(city) { placemarks, _ in
                continuation.resume(returning: placemarks?.first?.timeZone)
            }
        }
    }

    // MARK: - Helpers

    private var uniqueCities: [String] {
        Array(Set(trip.days.map(\.cityName).filter { !$0.isEmpty })).sorted()
    }

    private var tripDateRange: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "d MMM"
        let start = formatter.string(from: trip.startDate)
        let end = formatter.string(from: trip.endDate)
        return "\(start) – \(end) // \(trip.totalDays) дн."
    }

}
