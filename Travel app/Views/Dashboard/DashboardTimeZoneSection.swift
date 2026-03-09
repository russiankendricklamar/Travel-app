import SwiftUI
import CoreLocation

struct DashboardTimeZoneSection: View {
    let trip: Trip

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
        if !homeCity.isEmpty && !destinationCity.isEmpty {
            timeZoneCard
                .task { await resolveTimeZones() }
                .onAppear { startTimer() }
                .onDisappear { timer?.invalidate() }
        }
    }

    // MARK: - Card

    private var timeZoneCard: some View {
        HStack(spacing: 0) {
            // Home city
            clockColumn(
                icon: "house.fill",
                city: homeCity,
                timeZone: homeTimeZone ?? .current,
                alignment: .leading
            )

            // Divider + time difference
            VStack(spacing: 4) {
                if let diff = timeDifference {
                    Text(diff)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.sakuraPink)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(AppTheme.sakuraPink.opacity(0.1))
                        .clipShape(Capsule())
                }

                Rectangle()
                    .fill(AppTheme.sakuraPink.opacity(0.2))
                    .frame(width: 1, height: 24)
            }

            // Destination city
            clockColumn(
                icon: trip.isActive ? "location.fill" : "airplane",
                city: destinationCity,
                timeZone: destinationTimeZone ?? .current,
                alignment: .trailing
            )
        }
        .padding(.horizontal, AppTheme.spacingM)
        .padding(.vertical, AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(AppTheme.sakuraPink.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - Clock Column

    private func clockColumn(
        icon: String,
        city: String,
        timeZone: TimeZone,
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            HStack(spacing: 4) {
                if alignment == .leading {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppTheme.sakuraPink.opacity(0.6))
                }
                Text(city.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if alignment == .trailing {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppTheme.sakuraPink.opacity(0.6))
                }
            }

            Text(formattedTime(in: timeZone))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .animation(.default, value: formattedTime(in: timeZone))

            Text(formattedDate(in: timeZone))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Formatting

    private func formattedTime(in tz: TimeZone) -> String {
        let f = DateFormatter()
        f.timeZone = tz
        f.dateFormat = "HH:mm"
        return f.string(from: currentTime)
    }

    private func formattedDate(in tz: TimeZone) -> String {
        let f = DateFormatter()
        f.timeZone = tz
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMM, EE"
        return f.string(from: currentTime).lowercased()
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

    // MARK: - Timer

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            currentTime = Date()
        }
    }

    // MARK: - Geocoding

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
}
