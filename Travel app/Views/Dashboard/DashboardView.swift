import SwiftUI
import SwiftData

struct DashboardView: View {
    let trip: Trip
    @Binding var showSideMenu: Bool

    @State private var heroScale: CGFloat = 0.8
    @State private var statsOffset: CGFloat = 60
    @State private var budgetWidth: CGFloat = 0
    @State private var counterValue: Int = 0
    @State private var showPackingList = false
    @State private var showAddFlight = false

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
                        packingMiniCard
                        flightOrAddCard
                        DashboardWeatherSection(trip: trip)
                    case .active:
                        DashboardActiveSection(
                            trip: trip,
                            heroScale: heroScale,
                            statsOffset: statsOffset,
                            counterValue: counterValue,
                            budgetWidth: budgetWidth
                        )
                        DashboardTimeZoneSection(trip: trip)
                        DashboardTodayScheduleSection(trip: trip)
                        DashboardCountryInfoSection(trip: trip)
                        packingMiniCard
                        flightOrAddCard
                        DashboardWeatherSection(trip: trip)
                    case .postTrip:
                        postTripHero
                        statsBanner
                        DashboardBudgetSection(trip: trip, budgetWidth: budgetWidth)
                        if !trip.allJournalEntries.isEmpty {
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddFlight = true
                    } label: {
                        Image(systemName: "airplane")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.oceanBlue)
                    }
                }
            }
            .onAppear {
                animateIn()
                startCountdownTimer()
            }
            .onDisappear {
                countdownTimer?.invalidate()
            }
            .sheet(isPresented: $showAddFlight) {
                EditFlightSheet(trip: trip)
            }
        }
    }

    // MARK: - Flight or Add Card

    @ViewBuilder
    private var flightOrAddCard: some View {
        if !trip.flights.isEmpty {
            DashboardFlightTrackingSection(trip: trip)
        }
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

    // MARK: - Packing Mini Card

    private var packingMiniCard: some View {
        Button {
            showPackingList = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "bag.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(trip.packingProgress >= 1.0 ? AppTheme.bambooGreen : AppTheme.oceanBlue)
                    .frame(width: 36, height: 36)
                    .background((trip.packingProgress >= 1.0 ? AppTheme.bambooGreen : AppTheme.oceanBlue).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text("СПИСОК ВЕЩЕЙ")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(.secondary)
                    Text("\(trip.totalPacked)/\(trip.packingItems.count) упаковано")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                }

                Spacer()

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.15))
                        Capsule()
                            .fill(trip.packingProgress >= 1.0 ? AppTheme.bambooGreen : AppTheme.oceanBlue)
                            .frame(width: geo.size.width * trip.packingProgress)
                    }
                }
                .frame(width: 60, height: 6)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(AppTheme.spacingM)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
        }
        .sheet(isPresented: $showPackingList) {
            PackingListView(trip: trip)
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

    // MARK: - Helpers

    private var uniqueCities: [String] {
        Array(Set(trip.days.map(\.cityName))).sorted()
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
