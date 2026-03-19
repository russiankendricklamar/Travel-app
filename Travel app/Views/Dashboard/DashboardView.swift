import SwiftUI
import SwiftData
import CoreLocation

struct DashboardView: View {
    let trip: Trip
    @Binding var showSideMenu: Bool

    @State private var heroScale: CGFloat = 0.8
    @State private var statsOffset: CGFloat = 60
    @State private var budgetWidth: CGFloat = 0
    @State private var counterValue: Int = 0

    // Countdown timer
    @State private var countdownTimer: Timer?
    @State private var countdownDays: Int = 0
    @State private var countdownHours: Int = 0
    @State private var countdownMinutes: Int = 0
    @State private var countdownSeconds: Int = 0

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: AppTheme.spacingM) {
                    if !OfflineCacheManager.shared.isOnline {
                        OfflineBanner()
                    }

                    switch trip.phase {
                    case .preTrip:
                        DashboardCountdownSection(
                            trip: trip,
                            heroScale: heroScale,
                            countdownDays: countdownDays,
                            countdownHours: countdownHours,
                            countdownMinutes: countdownMinutes,
                            countdownSeconds: countdownSeconds,
                            statsOffset: statsOffset
                        )
                        DashboardTimeZoneSection(trip: trip)
                        DashboardCountryInfoSection(trip: trip)
                        flightOrAddCard
                        DashboardWeatherSection(trip: trip)

                    case .active:
                        // 1. Day counter (compact) with timezone
                        DashboardActiveSection(
                            trip: trip,
                            heroScale: heroScale,
                            statsOffset: statsOffset,
                            counterValue: counterValue
                        )
                        // 2. Weather
                        DashboardWeatherSection(trip: trip)
                        // --- divider ---
                        sectionDivider
                        // 3. Today's schedule
                        DashboardTodayScheduleSection(trip: trip)
                        // --- divider ---
                        sectionDivider
                        // 4. Budget & expenses
                        activeStatsSection
                        // 5. Future flights (if any)
                        flightOrAddCard

                    case .postTrip:
                        postTripHero
                        statsBanner
                        DashboardBudgetSection(trip: trip, budgetWidth: budgetWidth)
                        if !trip.allJournalEntries.isEmpty {
                            journalLink
                        }
                    }
                    Spacer(minLength: 80)
                }
                .padding(.horizontal, AppTheme.spacingM)
            }
            .sakuraGradientBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showSideMenu.toggle()
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(AppTheme.sakuraPink)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(trip.flaggedCountriesDisplay.uppercased())
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .tracking(4)
                        .foregroundStyle(AppTheme.sakuraPink)
                }
            }
            .onAppear {
                animateIn()
                startCountdownTimer()
            }
            .onDisappear {
                countdownTimer?.invalidate()
            }
            .task {
                await resolveAndFixTimezones()
            }
        }
    }

    // MARK: - Flight or Add Card (future flights only)

    @ViewBuilder
    private var flightOrAddCard: some View {
        let now = Date()
        let fiveDaysFromNow = Calendar.current.date(byAdding: .day, value: 5, to: now) ?? now
        let soonFlights = trip.flights.filter { flight in
            guard let date = flight.date else { return false }
            return date > now && date <= fiveDaysFromNow
        }
        if !soonFlights.isEmpty {
            DashboardFlightTrackingSection(trip: trip, flights: soonFlights)
        }
    }

    // MARK: - Active Stats Section (budget + expenses)

    private var activeStatsSection: some View {
        VStack(spacing: AppTheme.spacingM) {
            DashboardBudgetSection(trip: trip, budgetWidth: budgetWidth)

            // Recent expenses
            if !trip.recentExpenses.isEmpty {
                VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                    HStack {
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(AppTheme.sakuraPink)
                                .frame(width: 4, height: 16)
                            Text("ПОСЛЕДНИЕ РАСХОДЫ")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(2)
                                .foregroundStyle(AppTheme.sakuraPink)
                        }
                        Spacer()
                        Text("\(trip.recentExpenses.count)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.sakuraPink.opacity(0.4))
                    }
                    .padding(.horizontal, 4)

                    ForEach(trip.recentExpenses) { expense in
                        expenseRow(expense: expense)
                    }
                }
            }
        }
    }

    private func expenseRow(expense: Expense) -> some View {
        HStack(spacing: AppTheme.spacingS) {
            Image(systemName: expense.category.systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(
                    LinearGradient(
                        colors: [AppTheme.expenseColor(for: expense.category), AppTheme.expenseColor(for: expense.category).opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))

            VStack(alignment: .leading, spacing: 2) {
                Text(expense.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(expense.category.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(CurrencyService.formatBase(expense.amount))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - Countdown Timer

    private func startCountdownTimer() {
        updateCountdown()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            updateCountdown()
        }
    }

    private func updateCountdown() {
        let now = Date()
        let nextFlightDate = trip.flights
            .compactMap(\.date)
            .filter { $0 > now }
            .min()

        if let flight = nextFlightDate {
            let components = Calendar.current.dateComponents(
                [.day, .hour, .minute, .second],
                from: now,
                to: flight
            )
            countdownDays = components.day ?? 0
            countdownHours = components.hour ?? 0
            countdownMinutes = components.minute ?? 0
            countdownSeconds = components.second ?? 0
        } else if let countdown = trip.countdownToStart {
            countdownDays = countdown.day ?? 0
            countdownHours = countdown.hour ?? 0
            countdownMinutes = countdown.minute ?? 0
            countdownSeconds = countdown.second ?? 0
        }
    }

    private func animateIn() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            heroScale = 1.0
        }
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.15)) {
            statsOffset = 0
        }
        withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
            budgetWidth = trip.budgetUsedPercent
        }
        animateCounter()
    }

    private func animateCounter() {
        let target = trip.currentDay
        guard target > 0 else { return }
        let step = max(1, target / 20)
        Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { timer in
            if counterValue >= target {
                counterValue = target
                timer.invalidate()
            } else {
                counterValue = min(counterValue + step, target)
            }
        }
    }

    // MARK: - Post Trip Hero

    private var postTripHero: some View {
        VStack(spacing: AppTheme.spacingS) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(AppTheme.bambooGreen)

            Text("ПОЕЗДКА ЗАВЕРШЕНА")
                .font(.system(size: 14, weight: .bold))
                .tracking(3)
                .foregroundStyle(.primary)

            Text(trip.name.uppercased())
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            Text(tripDateRange.uppercased())
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(AppTheme.spacingXL)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusXL))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusXL)
                .strokeBorder(
                    LinearGradient(
                        colors: [AppTheme.bambooGreen.opacity(0.4), AppTheme.bambooGreen.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: AppTheme.bambooGreen.opacity(0.15), radius: 16, x: 0, y: 8)
    }

    // MARK: - Stats Banner (Post-Trip)

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

    // MARK: - Journal Link (Post-Trip)

    private var journalLink: some View {
        NavigationLink {
            JournalMemoryBookView(trip: trip)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "book.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.indigoPurple)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.indigoPurple.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 2) {
                    Text("КНИГА ВОСПОМИНАНИЙ")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(.primary)
                    Text("\(trip.allJournalEntries.count) записей")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(AppTheme.spacingM)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                    .strokeBorder(
                        LinearGradient(
                            colors: [AppTheme.indigoPurple.opacity(0.4), AppTheme.indigoPurple.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
    }

    // MARK: - Section Divider

    private var sectionDivider: some View {
        Rectangle()
            .fill(AppTheme.sakuraPink.opacity(0.18))
            .frame(height: 1)
            .padding(.horizontal, AppTheme.spacingS)
    }

    // MARK: - Timezone Resolution & One-Time Fix

    private func resolveAndFixTimezones() async {
        let geocoder = CLGeocoder()

        // Resolve home timezone from profile
        let profileService = ProfileService.shared
        let homeCity = profileService.profile?.homeCity ?? ""
        var homeTZ: TimeZone = .current
        if !homeCity.isEmpty,
           let placemarks = try? await geocoder.geocodeAddressString(homeCity),
           let tz = placemarks.first?.timeZone {
            homeTZ = tz
        }

        // Resolve and cache timezone for each day
        for day in trip.days where day.timezoneIdentifier.isEmpty && !day.cityName.isEmpty {
            if let placemarks = try? await geocoder.geocodeAddressString(day.cityName),
               let tz = placemarks.first?.timeZone {
                day.timezoneIdentifier = tz.identifier
            }
        }

        // One-time fix: events were created in Moscow (UTC+3) with intended
        // destination times, but stored as Moscow-local → UTC. Now in Tokyo (UTC+9),
        // they display +6h too late. Shift all events back by 6 hours.
        let fixKey = "timezoneFixApplied_v3_\(trip.id.uuidString)"
        guard !UserDefaults.standard.bool(forKey: fixKey) else { return }

        let shiftSeconds: TimeInterval = -6 * 3600 // Moscow→Tokyo offset
        for day in trip.days {
            for event in day.events {
                event.startTime = event.startTime.addingTimeInterval(shiftSeconds)
                event.endTime = event.endTime.addingTimeInterval(shiftSeconds)
            }
        }

        try? trip.modelContext?.save()
        UserDefaults.standard.set(true, forKey: fixKey)
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

#if DEBUG
#Preview {
    DashboardView(trip: .preview, showSideMenu: .constant(false))
        .modelContainer(.preview)
}
#endif
