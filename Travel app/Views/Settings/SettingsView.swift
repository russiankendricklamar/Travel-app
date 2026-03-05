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

    // AI Provider
    @AppStorage("aiProvider") private var aiProvider: String = AIProvider.groq.rawValue
    @State private var groqApiKey = Secrets.groqApiKey
    @State private var claudeApiKey = Secrets.claudeApiKey
    @State private var openaiApiKey = Secrets.openaiApiKey
    @State private var googlePlacesKey = Secrets.googlePlacesApiKey
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
                    aiProviderSection
                    googlePlacesSection
                    languageSection
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
                    color: AppTheme.oceanBlue,
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

    private func notifToggleWithPicker(title: LocalizedStringKey, icon: String, color: Color, isOn: Binding<Bool>, leadMinutes: Binding<Int>) -> some View {
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

    private var liveActivityToggle: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.badge.fill")
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

    // MARK: - AI Provider Section

    private var selectedProvider: AIProvider {
        AIProvider(rawValue: aiProvider) ?? .groq
    }

    private var aiProviderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("ИИ-ПОМОЩНИК", icon: "sparkles")

            HStack(spacing: 8) {
                ForEach(AIProvider.allCases) { provider in
                    aiProviderButton(provider)
                }
            }

            if selectedProvider == .groq {
                aiKeyField(
                    title: "Groq API-ключ",
                    hint: "gsk_...",
                    url: "console.groq.com",
                    binding: $groqApiKey
                )
            }

            if selectedProvider == .claude {
                aiKeyField(
                    title: "Claude API-ключ",
                    hint: "sk-ant-...",
                    url: "console.anthropic.com",
                    binding: $claudeApiKey
                )
            }

            if selectedProvider == .openai {
                aiKeyField(
                    title: "OpenAI API-ключ",
                    hint: "sk-...",
                    url: "platform.openai.com",
                    binding: $openaiApiKey
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
        .onChange(of: groqApiKey) { _, newValue in
            Secrets.setGroqApiKey(newValue)
        }
        .onChange(of: claudeApiKey) { _, newValue in
            Secrets.setClaudeApiKey(newValue)
        }
        .onChange(of: openaiApiKey) { _, newValue in
            Secrets.setOpenaiApiKey(newValue)
        }
    }

    private func aiProviderButton(_ provider: AIProvider) -> some View {
        let isSelected = selectedProvider == provider
        return Button {
            withAnimation(.spring(response: 0.3)) {
                aiProvider = provider.rawValue
                PlaceInfoService.shared.clearCache()
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: provider.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(isSelected ? .white : .primary)

                Text(provider.label)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(isSelected ? .white : .primary)

                Text(provider.subtitle)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.7) : Color.secondary.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isSelected ? AppTheme.indigoPurple : Color.clear)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .stroke(isSelected ? AppTheme.indigoPurple : Color.white.opacity(0.15), lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
    }

    private func aiKeyField(title: String, hint: String, url: String, binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SecureField(hint, text: binding)
                .font(.system(size: 13, design: .monospaced))
                .textFieldStyle(GlassTextFieldStyle())

            Text("Получить ключ: \(url)")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Google Places Section

    private var googlePlacesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("ПОИСК МЕСТ", icon: "location.magnifyingglass")

            VStack(alignment: .leading, spacing: 8) {
                SecureField("Google Places API-ключ", text: $googlePlacesKey)
                    .font(.system(size: 13, design: .monospaced))
                    .textFieldStyle(GlassTextFieldStyle())
                    .onChange(of: googlePlacesKey) { _, newValue in
                        Secrets.setGooglePlacesApiKey(newValue)
                    }

                Text("console.cloud.google.com → Places API (New)")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
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
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        } catch {
            // Silently handle — data reset is best-effort
        }
    }
}
