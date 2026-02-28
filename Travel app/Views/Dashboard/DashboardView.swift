import SwiftUI
import SwiftData

struct DashboardView: View {
    let trip: Trip

    @State private var appeared = false
    @State private var heroScale: CGFloat = 0.8
    @State private var statsOffset: CGFloat = 60
    @State private var budgetWidth: CGFloat = 0
    @State private var counterValue: Int = 0
    @State private var glitchFlicker = false

    // Countdown timer
    @State private var countdownTimer: Timer?
    @State private var countdownDays: Int = 0
    @State private var countdownHours: Int = 0
    @State private var countdownMinutes: Int = 0
    @State private var countdownSeconds: Int = 0

    private func formatYen(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        let formatted = formatter.string(from: NSNumber(value: Int(amount))) ?? "0"
        return "\u{00A5}\(formatted)"
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    switch trip.phase {
                    case .preTrip:
                        countdownHeroSection
                        flightInfoSection
                        suicaWalletSection
                    case .active:
                        heroSection
                        pinkBanner
                        statsSection
                        budgetSection
                        recentExpensesSection
                        suicaWalletSection
                    case .postTrip:
                        postTripHero
                        pinkBanner
                        statsSection
                        budgetSection
                    }
                    Spacer(minLength: 80)
                }
            }
            .background(AppTheme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Rectangle()
                            .fill(AppTheme.sakuraPink)
                            .frame(width: 12, height: 3)
                        Text("JAPAN")
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .tracking(6)
                            .foregroundStyle(AppTheme.sakuraPink)
                        Rectangle()
                            .fill(AppTheme.sakuraPink)
                            .frame(width: 12, height: 3)
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
        withAnimation(.easeInOut(duration: 0.1).delay(0.4)) {
            glitchFlicker = true
        }
        withAnimation(.easeInOut(duration: 0.1).delay(0.5)) {
            glitchFlicker = false
        }
        appeared = true
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

    // MARK: - Pre-Trip Countdown Hero

    private var countdownHeroSection: some View {
        VStack(spacing: 0) {
            ZStack {
                Rectangle()
                    .fill(AppTheme.sakuraPink.opacity(0.1))
                    .offset(x: -4, y: -4)
                Rectangle()
                    .fill(AppTheme.sakuraPink.opacity(0.15))
                    .offset(x: 6, y: 6)

                VStack(spacing: AppTheme.spacingM) {
                    Spacer(minLength: 24)

                    Text("ВЫЛЕТ ЧЕРЕЗ")
                        .font(.system(size: 11, weight: .black))
                        .tracking(6)
                        .foregroundStyle(AppTheme.sakuraPink)

                    Text("\(countdownDays)")
                        .font(.system(size: 140, weight: .black, design: .monospaced))
                        .foregroundStyle(AppTheme.textPrimary)
                        .shadow(color: AppTheme.sakuraPink.opacity(0.2), radius: 0, x: 4, y: 4)
                        .contentTransition(.numericText())
                        .animation(.default, value: countdownDays)

                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(AppTheme.sakuraPink)
                            .frame(height: 2)
                        Text(daysWord(countdownDays))
                            .font(.system(size: 13, weight: .black))
                            .tracking(4)
                            .foregroundStyle(AppTheme.sakuraPink)
                            .fixedSize()
                        Rectangle()
                            .fill(AppTheme.sakuraPink)
                            .frame(height: 2)
                    }
                    .padding(.horizontal, AppTheme.spacingL)

                    HStack(spacing: 4) {
                        countdownUnit(value: countdownHours, label: "ЧАС")
                        countdownSeparator
                        countdownUnit(value: countdownMinutes, label: "МИН")
                        countdownSeparator
                        countdownUnit(value: countdownSeconds, label: "СЕК")
                    }
                    .padding(.top, 4)

                    Spacer(minLength: 24)
                }
                .frame(maxWidth: .infinity)
                .background(AppTheme.card)
                .overlay(
                    Rectangle()
                        .stroke(AppTheme.sakuraPink, lineWidth: 4)
                )
            }
            .padding(.horizontal, AppTheme.spacingM)
            .padding(.top, 8)
            .scaleEffect(heroScale)
        }
    }

    private func countdownUnit(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text(String(format: "%02d", value))
                .font(.system(size: 32, weight: .black, design: .monospaced))
                .foregroundStyle(AppTheme.textPrimary)
                .contentTransition(.numericText())
                .animation(.default, value: value)
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .tracking(2)
                .foregroundStyle(AppTheme.textMuted)
        }
        .frame(width: 70)
        .padding(.vertical, 8)
        .background(AppTheme.surface)
        .overlay(Rectangle().stroke(AppTheme.border, lineWidth: 1))
    }

    private var countdownSeparator: some View {
        Text(":")
            .font(.system(size: 28, weight: .black, design: .monospaced))
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

    private var flightInfoSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(AppTheme.sakuraPink)
                    .frame(width: 5)

                HStack {
                    Image(systemName: "airplane.departure")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.sakuraPink)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(trip.name.uppercased())
                            .font(.system(size: 11, weight: .black))
                            .tracking(2)
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(tripDateRange.uppercased())
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("РЕЙС")
                            .font(.system(size: 8, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(AppTheme.textMuted)
                        if let flight = trip.flightDate {
                            Text(flightDateFormatted(flight))
                                .font(.system(size: 13, weight: .black, design: .monospaced))
                                .foregroundStyle(AppTheme.sakuraPink)
                        }
                    }
                }
                .padding(AppTheme.spacingM)
            }
            .background(AppTheme.card)
            .overlay(Rectangle().stroke(AppTheme.border, lineWidth: 2))
        }
        .padding(.horizontal, AppTheme.spacingM)
        .padding(.top, AppTheme.spacingM)
        .offset(y: statsOffset)
    }

    private func flightDateFormatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMM, HH:mm"
        return f.string(from: date)
    }

    // MARK: - Active Trip Hero

    private var heroSection: some View {
        ZStack {
            Rectangle()
                .fill(AppTheme.sakuraPink.opacity(0.15))
                .frame(height: 300)
                .offset(x: -4, y: -4)

            Rectangle()
                .fill(AppTheme.sakuraPink.opacity(0.25))
                .frame(height: 300)
                .offset(x: glitchFlicker ? 8 : 6, y: 6)

            VStack(spacing: 0) {
                Spacer(minLength: 16)

                ZStack {
                    Text("\(counterValue)")
                        .font(.system(size: 160, weight: .black, design: .monospaced))
                        .foregroundStyle(AppTheme.sakuraPink.opacity(0.08))
                        .blur(radius: 20)

                    Text("\(counterValue)")
                        .font(.system(size: 160, weight: .black, design: .monospaced))
                        .foregroundStyle(AppTheme.textPrimary)
                        .shadow(color: AppTheme.sakuraPink.opacity(0.3), radius: 0, x: 4, y: 4)
                }

                HStack(spacing: 8) {
                    Rectangle()
                        .fill(AppTheme.sakuraPink)
                        .frame(height: 2)
                    Text("ДЕНЬ ПУТЕШЕСТВИЯ")
                        .font(.system(size: 11, weight: .black))
                        .tracking(5)
                        .foregroundStyle(AppTheme.sakuraPink)
                        .fixedSize()
                    Rectangle()
                        .fill(AppTheme.sakuraPink)
                        .frame(height: 2)
                }
                .padding(.horizontal, AppTheme.spacingL)

                Spacer(minLength: 12)

                Text(trip.name.uppercased())
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)

                Text(tripDateRange.uppercased())
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(AppTheme.textMuted)
                    .padding(.top, 4)

                Spacer(minLength: 16)
            }
            .frame(height: 300)
            .frame(maxWidth: .infinity)
            .background(AppTheme.card)
            .overlay(
                Rectangle()
                    .stroke(AppTheme.sakuraPink, lineWidth: 4)
            )
        }
        .padding(.horizontal, AppTheme.spacingM)
        .padding(.top, 8)
        .scaleEffect(heroScale)
    }

    // MARK: - Post Trip Hero

    private var postTripHero: some View {
        VStack(spacing: 0) {
            VStack(spacing: AppTheme.spacingS) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(AppTheme.bambooGreen)

                Text("ПОЕЗДКА ЗАВЕРШЕНА")
                    .font(.system(size: 14, weight: .black))
                    .tracking(4)
                    .foregroundStyle(AppTheme.textPrimary)

                Text(trip.name.uppercased())
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)

                Text(tripDateRange.uppercased())
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.textMuted)
            }
            .padding(AppTheme.spacingXL)
            .frame(maxWidth: .infinity)
            .background(AppTheme.card)
            .overlay(Rectangle().stroke(AppTheme.border, lineWidth: 4))
        }
        .padding(.horizontal, AppTheme.spacingM)
        .padding(.top, 8)
    }

    private var tripDateRange: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM"
        let start = formatter.string(from: trip.startDate)
        let end = formatter.string(from: trip.endDate)
        return "\(start) – \(end) // \(trip.totalDays) дн."
    }

    // MARK: - Suica Wallet Section

    private var suicaWalletSection: some View {
        Button {
            if let url = URL(string: "shoebox://") {
                UIApplication.shared.open(url) { success in
                    if !success {
                        if let appStore = URL(string: "https://apps.apple.com/app/suica/id1156875272") {
                            UIApplication.shared.open(appStore)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(AppTheme.bambooGreen)
                    .frame(width: 5)

                HStack(spacing: AppTheme.spacingS) {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.bambooGreen)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("SUICA")
                            .font(.system(size: 12, weight: .black))
                            .tracking(2)
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("ОТКРЫТЬ APPLE WALLET")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(AppTheme.textMuted)
                    }

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.bambooGreen)
                }
                .padding(AppTheme.spacingM)
            }
            .background(AppTheme.card)
            .overlay(Rectangle().stroke(AppTheme.border, lineWidth: 2))
        }
        .padding(.horizontal, AppTheme.spacingM)
        .padding(.top, AppTheme.spacingM)
        .offset(y: statsOffset)
    }

    // MARK: - Pink Banner

    private var pinkBanner: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Rectangle().fill(AppTheme.sakuraPink).frame(height: 4)
            }
            .padding(.horizontal, AppTheme.spacingM)

            HStack(spacing: 0) {
                bannerStat("\(trip.placesVisitedCount)/\(trip.totalPlacesCount)", label: "МЕСТ", icon: "mappin.and.ellipse")
                Rectangle().fill(.white.opacity(0.2)).frame(width: 2)
                bannerStat("\(uniqueCities.count)", label: "ГОРОДОВ", icon: "building.2")
                Rectangle().fill(.white.opacity(0.2)).frame(width: 2)
                bannerStat(formatYen(trip.totalSpent), label: "ПОТРАЧЕНО", icon: "yensign")
            }
            .frame(height: 80)
            .background(AppTheme.sakuraPink)
            .padding(.horizontal, AppTheme.spacingM)
        }
        .padding(.top, 4)
        .offset(y: statsOffset)
    }

    private func bannerStat(_ value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.6))
            Text(value)
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }

    private var uniqueCities: [String] {
        Array(Set(trip.days.map(\.cityName))).sorted()
    }

    // MARK: - Stats

    private var statsSection: some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                boldStat(
                    value: "\(trip.journalEntries.count)",
                    label: "ЗАПИСЕЙ",
                    icon: "book.fill",
                    color: AppTheme.sakuraPink
                )
                boldStat(
                    value: "\(Int(trip.budgetUsedPercent * 100))%",
                    label: "БЮДЖЕТА",
                    icon: "chart.bar.fill",
                    color: AppTheme.templeGold
                )
            }
        }
        .padding(.horizontal, AppTheme.spacingM)
        .padding(.top, AppTheme.spacingM)
        .offset(y: statsOffset)
    }

    private func boldStat(value: String, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(color)
                .frame(width: 5)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(value)
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundStyle(color)
                    Text(label)
                        .font(.system(size: 9, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(AppTheme.textMuted)
                }
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(color.opacity(0.15))
            }
            .padding(AppTheme.spacingM)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .overlay(Rectangle().stroke(AppTheme.border, lineWidth: 2))
    }

    // MARK: - Budget

    private var budgetSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "yensign.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.sakuraPink)
                    Text("БЮДЖЕТ")
                        .font(.system(size: 11, weight: .black))
                        .tracking(4)
                        .foregroundStyle(AppTheme.sakuraPink)
                }
                Spacer()
                Text(formatYen(trip.budget))
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(AppTheme.spacingM)
            .background(AppTheme.card)
            .overlay(
                Rectangle()
                    .fill(AppTheme.sakuraPink)
                    .frame(height: 3),
                alignment: .bottom
            )

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(AppTheme.surface)

                    Rectangle()
                        .fill(budgetBarColor)
                        .frame(width: geo.size.width * budgetWidth)

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.2), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: geo.size.width * budgetWidth)

                    Text("\(Int(trip.budgetUsedPercent * 100))%")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                        .padding(.leading, 12)
                }
            }
            .frame(height: 52)

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ПОТРАЧЕНО")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(AppTheme.textMuted)
                    Text(formatYen(trip.totalSpent))
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundStyle(AppTheme.toriiRed)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppTheme.spacingS)

                Rectangle().fill(AppTheme.sakuraPink.opacity(0.3)).frame(width: 3)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("ОСТАТОК")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(AppTheme.textMuted)
                    Text(formatYen(trip.remainingBudget))
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundStyle(trip.remainingBudget >= 0 ? AppTheme.bambooGreen : AppTheme.toriiRed)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(AppTheme.spacingS)
            }
            .background(AppTheme.card)

            if !trip.expensesByCategory.isEmpty {
                let maxAmount = trip.expensesByCategory.first?.total ?? 1
                ForEach(trip.expensesByCategory, id: \.category) { item in
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(AppTheme.expenseColor(for: item.category))
                            .frame(width: 5)

                        HStack(spacing: 8) {
                            Image(systemName: item.category.systemImage)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(AppTheme.expenseColor(for: item.category))
                                .frame(width: 24, height: 24)
                                .background(AppTheme.expenseColor(for: item.category).opacity(0.1))

                            Text(item.category.rawValue.uppercased())
                                .font(.system(size: 9, weight: .black))
                                .tracking(1)
                                .foregroundStyle(AppTheme.textSecondary)

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(AppTheme.surface)
                                    Rectangle()
                                        .fill(AppTheme.expenseColor(for: item.category).opacity(0.3))
                                        .frame(width: geo.size.width * (item.total / maxAmount))
                                }
                            }
                            .frame(height: 10)

                            Text(formatYen(item.total))
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                        .padding(.horizontal, AppTheme.spacingS)
                        .padding(.vertical, 8)
                    }
                    .background(AppTheme.card)
                }
            }
        }
        .overlay(Rectangle().stroke(AppTheme.border, lineWidth: 2))
        .padding(.horizontal, AppTheme.spacingM)
        .padding(.top, AppTheme.spacingM)
    }

    private var budgetBarColor: Color {
        if trip.budgetUsedPercent > 0.9 { return AppTheme.toriiRed }
        if trip.budgetUsedPercent > 0.7 { return AppTheme.templeGold }
        return AppTheme.bambooGreen
    }

    // MARK: - Recent Expenses

    private var recentExpensesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(AppTheme.sakuraPink)
                    .frame(width: 5)

                HStack {
                    Text("ПОСЛЕДНИЕ РАСХОДЫ")
                        .font(.system(size: 11, weight: .black))
                        .tracking(4)
                        .foregroundStyle(AppTheme.sakuraPink)
                    Spacer()
                    Text("\(trip.recentExpenses.count)")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundStyle(AppTheme.sakuraPink.opacity(0.4))
                }
                .padding(AppTheme.spacingM)
            }
            .background(AppTheme.card)

            ForEach(Array(trip.recentExpenses.enumerated()), id: \.element.id) { index, expense in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(AppTheme.expenseColor(for: expense.category))
                        .frame(width: 4)

                    HStack(spacing: AppTheme.spacingS) {
                        Text(String(format: "%02d", index + 1))
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                            .foregroundStyle(AppTheme.sakuraPink.opacity(0.2))
                            .frame(width: 38)

                        Rectangle()
                            .fill(AppTheme.border)
                            .frame(width: 2, height: 40)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(expense.title.uppercased())
                                .font(.system(size: 11, weight: .bold))
                                .tracking(0.5)
                                .foregroundStyle(AppTheme.textPrimary)
                                .lineLimit(1)

                            Text(expense.category.rawValue.uppercased())
                                .font(.system(size: 8, weight: .black))
                                .tracking(1.5)
                                .foregroundStyle(AppTheme.expenseColor(for: expense.category))
                        }

                        Spacer()

                        Text(formatYen(expense.amount))
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    .padding(.horizontal, AppTheme.spacingS)
                    .padding(.vertical, AppTheme.spacingS)
                }
                .background(index % 2 == 0 ? AppTheme.card : AppTheme.surface)
            }
        }
        .overlay(Rectangle().stroke(AppTheme.border, lineWidth: 2))
        .padding(.horizontal, AppTheme.spacingM)
        .padding(.top, AppTheme.spacingM)
    }
}

#if DEBUG
#Preview {
    DashboardView(trip: .preview)
        .modelContainer(.preview)
}
#endif
