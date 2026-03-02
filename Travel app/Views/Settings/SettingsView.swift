import SwiftUI
import SwiftData

struct SettingsView: View {
    let trip: Trip
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // Palette
    @AppStorage("colorPalette") private var palette: String = ColorPalette.sakura.rawValue

    // Notifications
    @AppStorage("notif_morning") private var notifMorning = true
    @AppStorage("notif_event") private var notifEvent = true
    @AppStorage("notif_budget") private var notifBudget = true
    @AppStorage("notif_weather") private var notifWeather = true
    @AppStorage("liveActivityEnabled") private var liveActivityEnabled = true

    // Notification times (stored as hour * 60 + minute)
    @AppStorage("notif_morning_time") private var morningTimeMinutes = 480   // 8:00
    @AppStorage("notif_event_lead") private var eventLeadMinutes = 30       // 30 min before
    @AppStorage("notif_weather_morning_time") private var weatherMorningMinutes = 480  // 8:00
    @AppStorage("notif_weather_evening_time") private var weatherEveningMinutes = 1260 // 21:00

    // Bindings for DatePicker
    private var morningTime: Binding<Date> {
        timeBinding(minutes: $morningTimeMinutes)
    }
    private var weatherMorningTime: Binding<Date> {
        timeBinding(minutes: $weatherMorningMinutes)
    }
    private var weatherEveningTime: Binding<Date> {
        timeBinding(minutes: $weatherEveningMinutes)
    }

    private func timeBinding(minutes: Binding<Int>) -> Binding<Date> {
        Binding<Date>(
            get: {
                let h = minutes.wrappedValue / 60
                let m = minutes.wrappedValue % 60
                return Calendar.current.date(from: DateComponents(hour: h, minute: m)) ?? Date()
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                minutes.wrappedValue = (comps.hour ?? 8) * 60 + (comps.minute ?? 0)
            }
        )
    }

    // Currency
    @AppStorage("preferredCurrency") private var currency = "RUB"
    @AppStorage("useCustomRates") private var useCustomRates = false
    @AppStorage("customRate_JPY") private var customRateJPY: Double = 0.59
    @AppStorage("customRate_USD") private var customRateUSD: Double = 88.0
    @AppStorage("customRate_CNY") private var customRateCNY: Double = 12.2

    @State private var showResetConfirmation = false

    private var selectedPalette: ColorPalette {
        ColorPalette(rawValue: palette) ?? .sakura
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacingL) {
                    paletteSection
                    notificationSection
                    currencySection
                    exchangeRatesSection
                    languageSection
                    dataSection
                    aboutSection
                }
                .padding(AppTheme.spacingM)
            }
            .sakuraGradientBackground()
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .confirmationDialog(
                "Сбросить все данные?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Удалить всё", role: .destructive) {
                    resetAllData()
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Это удалит все поездки, расходы и записи. Действие нельзя отменить.")
            }
        }
    }

    // MARK: - Palette Section

    private var paletteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("ПАЛИТРА", icon: "paintbrush.fill")

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
            ], spacing: 10) {
                ForEach(ColorPalette.allCases) { p in
                    paletteOption(p)
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
    }

    private func paletteOption(_ p: ColorPalette) -> some View {
        let isSelected = selectedPalette == p
        return Button {
            withAnimation(.spring(response: 0.3)) {
                palette = p.rawValue
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                        .fill(
                            LinearGradient(
                                colors: p.backgroundColors,
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                                .stroke(isSelected ? p.accentColor : Color.clear, lineWidth: 2)
                        )

                    Circle()
                        .fill(p.accentColor)
                        .frame(width: 16, height: 16)
                        .shadow(color: p.accentColor.opacity(0.5), radius: 4, x: 0, y: 2)
                }

                Text(p.label)
                    .font(.system(size: 9, weight: isSelected ? .bold : .medium))
                    .tracking(0.5)
                    .foregroundStyle(isSelected ? AppTheme.sakuraPink : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    // MARK: - Notification Section

    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("УВЕДОМЛЕНИЯ", icon: "bell.fill")

            notifToggleWithTime(
                title: "Утренний план",
                icon: "sunrise.fill",
                color: AppTheme.templeGold,
                isOn: $notifMorning,
                time: morningTime
            )
            notifToggleWithPicker(
                title: "Напоминания о событиях",
                icon: "clock.fill",
                color: AppTheme.sakuraPink,
                isOn: $notifEvent,
                leadMinutes: $eventLeadMinutes
            )
            notifToggle(
                title: "Бюджет",
                subtitle: "Когда потрачено > 80%",
                icon: "rublesign.circle.fill",
                color: AppTheme.toriiRed,
                isOn: $notifBudget
            )
            notifToggleWithTwoTimes(
                title: "Прогноз погоды",
                icon: "cloud.sun.fill",
                color: AppTheme.oceanBlue,
                isOn: $notifWeather,
                morningTime: weatherMorningTime,
                eveningTime: weatherEveningTime
            )
            liveActivityToggle
        }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
    }

    private func notifToggle(title: String, subtitle: String, icon: String, color: Color, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(AppTheme.sakuraPink)
        }
        .padding(10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
    }

    private func notifToggleWithTime(title: String, icon: String, color: Color, isOn: Binding<Bool>, time: Binding<Date>) -> some View {
        VStack(spacing: 0) {
            notifToggle(title: title, subtitle: formatTimeMinutes(time.wrappedValue), icon: icon, color: color, isOn: isOn)
            if isOn.wrappedValue {
                DatePicker("", selection: time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(height: 100)
                    .clipped()
                    .padding(.horizontal, 10)
            }
        }
    }

    private func notifToggleWithPicker(title: String, icon: String, color: Color, isOn: Binding<Bool>, leadMinutes: Binding<Int>) -> some View {
        VStack(spacing: 0) {
            notifToggle(title: title, subtitle: "За \(leadMinutes.wrappedValue) мин до начала", icon: icon, color: color, isOn: isOn)
            if isOn.wrappedValue {
                HStack(spacing: 8) {
                    ForEach([15, 30, 60], id: \.self) { mins in
                        let selected = leadMinutes.wrappedValue == mins
                        Button {
                            withAnimation(.spring(response: 0.3)) { leadMinutes.wrappedValue = mins }
                        } label: {
                            Text("\(mins) мин")
                                .font(.system(size: 12, weight: .bold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .foregroundStyle(selected ? .white : .secondary)
                                .background(selected ? color : .clear)
                                .background { if !selected { Color.clear.background(.ultraThinMaterial) } }
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(selected ? color.opacity(0.5) : Color.white.opacity(0.2), lineWidth: 0.5))
                        }
                    }
                    Spacer()
                }
                .padding(10)
            }
        }
    }

    private func notifToggleWithTwoTimes(title: String, icon: String, color: Color, isOn: Binding<Bool>, morningTime: Binding<Date>, eveningTime: Binding<Date>) -> some View {
        VStack(spacing: 0) {
            notifToggle(title: title, subtitle: "\(formatTimeMinutes(morningTime.wrappedValue)) и \(formatTimeMinutes(eveningTime.wrappedValue))", icon: icon, color: color, isOn: isOn)
            if isOn.wrappedValue {
                VStack(spacing: 6) {
                    HStack {
                        Text("Утро")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        DatePicker("", selection: morningTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .tint(color)
                    }
                    HStack {
                        Text("Вечер")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        DatePicker("", selection: eveningTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .tint(color)
                    }
                }
                .padding(10)
            }
        }
    }

    private var liveActivityToggle: some View {
        HStack(spacing: 12) {
            Image(systemName: "island.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(
                    LinearGradient(
                        colors: [AppTheme.indigoPurple, AppTheme.indigoPurple.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))

            VStack(alignment: .leading, spacing: 2) {
                Text("Live Activity")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("Dynamic Island + Lock Screen")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: $liveActivityEnabled)
                .labelsHidden()
                .tint(AppTheme.sakuraPink)
                .onChange(of: liveActivityEnabled) { _, enabled in
                    if !enabled {
                        LiveActivityManager.shared.endAllActivities()
                    }
                }
        }
        .padding(10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
    }

    private func formatTimeMinutes(_ date: Date) -> String {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%d:%02d", comps.hour ?? 0, comps.minute ?? 0)
    }

    // MARK: - Currency Section

    private var currencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("ВАЛЮТА", icon: "banknote.fill")

            HStack(spacing: 8) {
                ForEach(CurrencyService.supportedCurrencies, id: \.self) { code in
                    currencyButton(code)
                }
            }

            Text("Для отображения сумм. Хранение в RUB.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 4)
        }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
    }

    private func currencyButton(_ code: String) -> some View {
        let isSelected = currency == code
        let symbols = CurrencyService.symbols
        return Button {
            withAnimation(.spring(response: 0.3)) { currency = code }
        } label: {
            VStack(spacing: 4) {
                Text(symbols[code] ?? code)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? .white : .primary)
                Text(code)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? AppTheme.sakuraPink : Color.clear)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .stroke(isSelected ? AppTheme.sakuraPink : Color.white.opacity(0.15), lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
    }

    // MARK: - Exchange Rates Section

    private var exchangeRatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("КУРСЫ ВАЛЮТ", icon: "arrow.left.arrow.right")

            Toggle(isOn: $useCustomRates) {
                HStack(spacing: 8) {
                    Image(systemName: useCustomRates ? "hand.draw.fill" : "antenna.radiowaves.left.and.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.templeGold)
                    Text(useCustomRates ? "Свои курсы" : "Онлайн курсы")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                }
            }
            .tint(AppTheme.sakuraPink)
            .padding(10)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))

            if useCustomRates {
                customRateRow("JPY", binding: $customRateJPY)
                customRateRow("USD", binding: $customRateUSD)
                customRateRow("CNY", binding: $customRateCNY)
            } else {
                apiRatesView
            }
        }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
        .task {
            if !useCustomRates {
                await CurrencyService.shared.fetchRates()
            }
        }
    }

    private func customRateRow(_ code: String, binding: Binding<Double>) -> some View {
        HStack(spacing: 8) {
            Text("1 \(code)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .frame(width: 55, alignment: .leading)
            Text("=")
                .foregroundStyle(.secondary)
            TextField("88", value: binding, format: .number)
                .keyboardType(.decimalPad)
                .textFieldStyle(GlassTextFieldStyle())
                .frame(maxWidth: 100)
            Text("RUB")
                .font(.system(size: 11, weight: .bold))
                .tracking(1)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
    }

    private var apiRatesView: some View {
        let svc = CurrencyService.shared
        return VStack(spacing: 6) {
            ForEach(["JPY", "USD", "CNY"], id: \.self) { code in
                let rubPer = svc.rubPerUnit(of: code)
                HStack {
                    Text("1 \(code)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(rubPer > 0 ? "\u{20BD}\(String(format: "%.2f", rubPer))" : "—")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.templeGold)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }

            HStack {
                if let updated = svc.lastUpdated {
                    Text("Обновлено: \(updated, style: .relative) назад")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Button {
                    Task {
                        svc.invalidateCache()
                        await svc.fetchRates()
                    }
                } label: {
                    HStack(spacing: 4) {
                        if svc.isLoading {
                            ProgressView().scaleEffect(0.6)
                        }
                        Text("Обновить")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(AppTheme.templeGold)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 4)
        }
        .padding(.vertical, 8)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
    }

    // MARK: - Language Section

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("ЯЗЫК", icon: "globe")

            HStack(spacing: 12) {
                Image(systemName: "textformat")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.sakuraPink)
                    .frame(width: 34, height: 34)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))

                Text("Русский")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.sakuraPink)
            }
            .padding(10)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
        }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - Data Section

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("ДАННЫЕ", icon: "externaldrive.fill")

            Button {
                showResetConfirmation = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(
                            LinearGradient(
                                colors: [AppTheme.toriiRed, AppTheme.toriiRed.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Сбросить все данные")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.toriiRed)
                        Text("Удалить поездки, расходы и записи")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(10)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
            }
        }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.sakuraPink.opacity(0.3), AppTheme.sakuraPink.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                Text("JP")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.sakuraPink)
            }

            Text("Japan Travel")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.primary)

            Text("v1.0.0")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Text("Сделано с \u{2764}\u{FE0F} для Японии")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.spacingL)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.sakuraPink)
            Text(text)
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .foregroundStyle(AppTheme.sakuraPink)
        }
    }

    private func resetAllData() {
        do {
            try modelContext.delete(model: Trip.self)
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        } catch {
            // Silently handle — data reset is best-effort
        }
    }
}
