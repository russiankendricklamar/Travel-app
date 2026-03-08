import SwiftUI
import SwiftData

struct SettingsView: View {
    let trip: Trip?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // Palette
    @AppStorage("colorPalette") private var palette: String = ColorPalette.sakura.rawValue
    // @AppStorage("appMode") private var appMode: String = AppMode.personal.rawValue

    // Notifications
    @AppStorage("notif_morning") private var notifMorning = true
    @AppStorage("notif_event") private var notifEvent = true
    @AppStorage("notif_budget") private var notifBudget = true
    @AppStorage("notif_weather") private var notifWeather = true
    @AppStorage("liveActivityEnabled") private var liveActivityEnabled = true
    @AppStorage("geofence_enabled") private var geofenceEnabled = false
    @AppStorage("geofence_automark_visited") private var geofenceAutomark = false

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
    @AppStorage("customRate_EUR") private var customRateEUR: Double = 95.0
    @AppStorage("customRate_RUB") private var customRateRUB: Double = 0

    @AppStorage("appLanguage") private var appLanguage: String = "system"
    @State private var showResetConfirmation = false
    @State private var showSignOutConfirmation = false
    @State private var showAuthSheet = false

    private let authManager = AuthManager.shared

    private var selectedPalette: ColorPalette {
        ColorPalette(rawValue: palette) ?? .sakura
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacingL) {
                    accountSection
                    paletteSection
                    notificationSection
                    currencySection
                    exchangeRatesSection
                    languageSection
                    aiProviderSection
                    dataSection
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
            .confirmationDialog(
                "Выйти из аккаунта?",
                isPresented: $showSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Выйти", role: .destructive) {
                    Task { await authManager.signOut() }
                }
                Button("Отмена", role: .cancel) {}
            }
            .sheet(isPresented: $showAuthSheet) {
                AuthView { result in
                    showAuthSheet = false
                }
            }
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("АККАУНТ", icon: "person.fill")

            if authManager.isSignedIn {
                // Profile info
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.sakuraPink, AppTheme.sakuraPink.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)

                        Text(String((authManager.userName ?? "?").prefix(1)).uppercased())
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(authManager.userName ?? String(localized: "Пользователь"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)

                        if let email = authManager.userEmail {
                            Text(email)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    // Provider badge
                    if let provider = authManager.authProvider {
                        Text(provider == "apple" ? "Apple" : "Google")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.5)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.thinMaterial)
                            .clipShape(Capsule())
                    }
                }
                .padding(12)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))

                // Face ID toggle
                if authManager.checkBiometricAvailability() {
                    HStack(spacing: 12) {
                        Image(systemName: "faceid")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(
                                LinearGradient(
                                    colors: [AppTheme.oceanBlue, AppTheme.oceanBlue.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Face ID")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text("Блокировка при запуске")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { authManager.isBiometricEnabled },
                            set: { authManager.isBiometricEnabled = $0 }
                        ))
                        .labelsHidden()
                        .tint(AppTheme.sakuraPink)
                    }
                    .padding(10)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                }

                // Sign out button
                Button {
                    showSignOutConfirmation = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
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

                        Text("Выйти")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.toriiRed)

                        Spacer()
                    }
                    .padding(10)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                }
            } else {
                // Not signed in
                Button {
                    showAuthSheet = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(
                                LinearGradient(
                                    colors: [AppTheme.sakuraPink, AppTheme.sakuraPink.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusSmall))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Войти")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text("Apple ID или Google")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(10)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
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

    // MARK: - Palette Section

    // Corporate mode disabled
    // private var isCorporateMode: Bool {
    //     AppMode(rawValue: appMode) == .corporate
    // }

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
                title: "Уведомления о местах",
                subtitle: "Когда вы рядом с запланированным местом",
                icon: "location.circle.fill",
                color: AppTheme.bambooGreen,
                isOn: $geofenceEnabled
            )

            if geofenceEnabled {
                notifToggle(
                    title: "Авто-отметка посещения",
                    subtitle: "Автоматически отмечать место посещённым",
                    icon: "checkmark.circle.fill",
                    color: AppTheme.sakuraPink,
                    isOn: $geofenceAutomark
                )
            }
        }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
        .onChange(of: geofenceEnabled) { _, enabled in
            if !enabled {
                GeofenceManager.shared.deactivate()
            }
        }
    }

    private func notifToggle(title: LocalizedStringKey, subtitle: LocalizedStringKey, icon: String, color: Color, isOn: Binding<Bool>) -> some View {
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

    private func notifToggleWithTime(title: LocalizedStringKey, icon: String, color: Color, isOn: Binding<Bool>, time: Binding<Date>) -> some View {
        VStack(spacing: 0) {
            notifToggle(title: title, subtitle: "\(formatTimeMinutes(time.wrappedValue))", icon: icon, color: color, isOn: isOn)
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

    @State private var showCustomLeadPicker = false
    @State private var customLeadValue = ""

    private func notifToggleWithPicker(title: LocalizedStringKey, icon: String, color: Color, isOn: Binding<Bool>, leadMinutes: Binding<Int>) -> some View {
        let presets = [60, 120]
        let isCustom = !presets.contains(leadMinutes.wrappedValue)
        let subtitleText = leadMinutes.wrappedValue >= 60
            ? "За \(leadMinutes.wrappedValue / 60) ч до начала"
            : "За \(leadMinutes.wrappedValue) мин до начала"

        return VStack(spacing: 0) {
            notifToggle(title: title, subtitle: "\(subtitleText)", icon: icon, color: color, isOn: isOn)
            if isOn.wrappedValue {
                HStack(spacing: 8) {
                    ForEach(presets, id: \.self) { mins in
                        let selected = leadMinutes.wrappedValue == mins
                        Button {
                            withAnimation(.spring(response: 0.3)) { leadMinutes.wrappedValue = mins }
                        } label: {
                            Text(mins >= 60 ? "\(mins / 60) ч" : "\(mins) мин")
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
                    Button {
                        customLeadValue = "\(leadMinutes.wrappedValue)"
                        showCustomLeadPicker = true
                    } label: {
                        Text(isCustom ? "\(leadMinutes.wrappedValue) мин" : "Своё")
                            .font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .foregroundStyle(isCustom ? .white : .secondary)
                            .background(isCustom ? color : .clear)
                            .background { if !isCustom { Color.clear.background(.ultraThinMaterial) } }
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(isCustom ? color.opacity(0.5) : Color.white.opacity(0.2), lineWidth: 0.5))
                    }
                    Spacer()
                }
                .padding(10)
            }
        }
        .alert("Своё время", isPresented: $showCustomLeadPicker) {
            TextField("Минуты", text: $customLeadValue)
                .keyboardType(.numberPad)
            Button("Сохранить") {
                if let val = Int(customLeadValue), val > 0 {
                    leadMinutes.wrappedValue = val
                }
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Введите количество минут до начала события")
        }
    }

    private func notifToggleWithTwoTimes(title: LocalizedStringKey, icon: String, color: Color, isOn: Binding<Bool>, morningTime: Binding<Date>, eveningTime: Binding<Date>) -> some View {
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

            Text("Базовая валюта для хранения и отображения")
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
            CurrencyService.shared.invalidateCache()
            Task { await CurrencyService.shared.fetchRates() }
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
                ForEach(nonBaseCurrencies, id: \.self) { code in
                    customRateRow(code, binding: customRateBinding(for: code))
                }
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

    private var nonBaseCurrencies: [String] {
        CurrencyService.supportedCurrencies.filter { $0 != currency }
    }

    private func customRateBinding(for code: String) -> Binding<Double> {
        switch code {
        case "JPY": return $customRateJPY
        case "USD": return $customRateUSD
        case "CNY": return $customRateCNY
        case "EUR": return $customRateEUR
        case "RUB": return $customRateRUB
        default: return .constant(0)
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
            Text(currency)
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
            ForEach(nonBaseCurrencies, id: \.self) { code in
                let basePerUnit = svc.basePerUnit(of: code)
                HStack {
                    Text("1 \(code)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(basePerUnit > 0 ? "\(CurrencyService.baseCurrencySymbol)\(String(format: "%.2f", basePerUnit))" : "—")
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

            Picker("", selection: $appLanguage) {
                Text("Системный").tag("system")
                Text("Русский").tag("ru")
                Text("English").tag("en")
            }
            .pickerStyle(.segmented)
            .tint(AppTheme.sakuraPink)
            .onChange(of: appLanguage) { _, newValue in
                if newValue == "system" {
                    UserDefaults.standard.removeObject(forKey: "AppleLanguages")
                } else {
                    UserDefaults.standard.set([newValue], forKey: "AppleLanguages")
                }
            }

            Text("Перезапустите приложение для смены языка")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - AI Provider Section

    @State private var geminiKey: String = Secrets.geminiApiKey
    @State private var travelpayoutsKey: String = Secrets.travelpayoutsToken

    private var aiProviderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("GEMINI AI", icon: "diamond.fill")

            GlassFormField(label: "GEMINI API KEY (необязательно)", color: AppTheme.bambooGreen) {
                SecureField("Свой ключ...", text: $geminiKey)
                    .textFieldStyle(GlassTextFieldStyle())
                    .onChange(of: geminiKey) { _, newValue in
                        let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty {
                            Secrets.setGeminiApiKey(trimmed)
                        } else {
                            KeychainHelper.delete(key: "geminiApiKey")
                        }
                    }
            }

            if !geminiKey.trimmingCharacters(in: .whitespaces).isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.bambooGreen)
                    Text("Свой ключ — прямое подключение")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.bambooGreen)
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.sakuraPink)
                    Text("Облачный прокси — работает везде")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.sakuraPink)
                }
            }

            GlassFormField(label: "TRAVELPAYOUTS TOKEN", color: AppTheme.oceanBlue) {
                SecureField("Token...", text: $travelpayoutsKey)
                    .textFieldStyle(GlassTextFieldStyle())
                    .onChange(of: travelpayoutsKey) { _, newValue in
                        let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty {
                            Secrets.setTravelpayoutsToken(trimmed)
                        } else {
                            KeychainHelper.delete(key: "travelpayoutsToken")
                        }
                    }
            }

            if !Secrets.travelpayoutsToken.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.bambooGreen)
                    Text("Токен установлен")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.bambooGreen)
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

    // MARK: - Helpers

    private func sectionLabel(_ text: LocalizedStringKey, icon: String) -> some View {
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
            try modelContext.delete(model: BucketListItem.self)
            try modelContext.delete(model: OfflineMapCache.self)
            try modelContext.save()
            AICacheManager.shared.clearAll()
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        } catch {
            // Silently handle — data reset is best-effort
        }
    }
}
