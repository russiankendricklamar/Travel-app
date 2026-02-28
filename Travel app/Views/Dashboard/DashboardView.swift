import SwiftUI
import SwiftData

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
                    case .active:
                        DashboardActiveSection(
                            trip: trip,
                            heroScale: heroScale,
                            statsOffset: statsOffset,
                            counterValue: counterValue,
                            budgetWidth: budgetWidth
                        )
                    case .postTrip:
                        postTripHero
                        statsBanner
                        DashboardBudgetSection(trip: trip, budgetWidth: budgetWidth)
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
                    Text("JAPAN")
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
        if let flight = trip.flightDate, Date() < flight {
            let components = Calendar.current.dateComponents(
                [.day, .hour, .minute, .second],
                from: Date(),
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
        .padding(.top, 8)
    }

    // MARK: - Stats Banner (Post-Trip)

    private var statsBanner: some View {
        HStack(spacing: 0) {
            bannerStat("\(trip.placesVisitedCount)/\(trip.totalPlacesCount)", label: "МЕСТ", icon: "mappin.and.ellipse")
            Divider().frame(height: 40)
            bannerStat("\(uniqueCities.count)", label: "ГОРОДОВ", icon: "building.2")
            Divider().frame(height: 40)
            bannerStat(formatYen(trip.totalSpent), label: "ПОТРАЧЕНО", icon: "yensign")
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

    private func bannerStat(_ value: String, label: String, icon: String) -> some View {
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
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM"
        let start = formatter.string(from: trip.startDate)
        let end = formatter.string(from: trip.endDate)
        return "\(start) – \(end) // \(trip.totalDays) дн."
    }

    private func formatYen(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        let formatted = formatter.string(from: NSNumber(value: Int(amount))) ?? "0"
        return "\u{00A5}\(formatted)"
    }
}

#if DEBUG
#Preview {
    DashboardView(trip: .preview, showSideMenu: .constant(false))
        .modelContainer(.preview)
}
#endif
