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
    @AppStorage("notif_event_leads") private var eventLeadMinutesStr = "30"  // comma-separated
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
    private let syncManager = SyncManager.shared

    private var selectedPalette: ColorPalette {
        ColorPalette(rawValue: palette) ?? .sakura
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacingL) {
                    accountSection
                    exchangeRatesSection
                    paletteSection
                    notificationSection
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

                // Sync row
                syncRow

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

    private var syncRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
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
                Text(syncStatusText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                if let last = syncManager.lastSyncDate {
                    Text("\(last, style: .relative) назад")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if syncManager.state == .syncing {
                ProgressView().scaleEffect(0.7)
            } else {
                // Sync status dot
                Circle()
                    .fill(syncManager.lastSyncDate != nil ? AppTheme.bambooGreen : .secondary)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
        .onTapGesture {
            guard syncManager.state != .syncing else { return }
            Task { await syncManager.forceSync() }
        }
    }

    private var syncStatusText: String {
        switch syncManager.state {
        case .idle:
            return syncManager.lastSyncDate != nil ? String(localized: "Синхронизировано") : String(localized: "Синхронизация")
        case .syncing:
            return String(localized: "Синхронизация...")
        case .error:
            return String(localized: "Ошибка синхронизации")
        }
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
            eventReminderSection
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

    @State private var isEditingMorningTime = false

    private func notifToggleWithTime(title: LocalizedStringKey, icon: String, color: Color, isOn: Binding<Bool>, time: Binding<Date>) -> some View {
        VStack(spacing: 0) {
            // Row: icon + text (tappable) + toggle (independent)
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
                    Text("\(formatTimeMinutes(time.wrappedValue))")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    guard isOn.wrappedValue else { return }
                    withAnimation(.spring(response: 0.3)) {
                        isEditingMorningTime.toggle()
                    }
                }

                Spacer()

                if isOn.wrappedValue && !isEditingMorningTime {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.tertiary)
                }

                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .tint(AppTheme.sakuraPink)
            }
            .padding(10)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))

            if isOn.wrappedValue && isEditingMorningTime {
                VStack(spacing: 8) {
                    DatePicker("", selection: time, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(height: 120)
                        .clipped()

                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            isEditingMorningTime = false
                        }
                    } label: {
                        Text("Готово")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)
                            .background(color)
                            .clipShape(Capsule())
                    }
                }
                .padding(10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    @State private var isAddingReminder = false
    @State private var newReminderHours = 0
    @State private var newReminderMinutes = 30

    private var eventLeadMinutes: [Int] {
        eventLeadMinutesStr.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }.sorted()
    }

    private func addEventLead(_ minutes: Int) {
        var leads = eventLeadMinutes
        guard !leads.contains(minutes), minutes > 0 else { return }
        leads.append(minutes)
        leads.sort()
        eventLeadMinutesStr = leads.map(String.init).joined(separator: ",")
    }

    private func removeEventLead(_ minutes: Int) {
        let leads = eventLeadMinutes.filter { $0 != minutes }
        eventLeadMinutesStr = leads.isEmpty ? "" : leads.map(String.init).joined(separator: ",")
    }

    private func formatLead(_ mins: Int) -> String {
        let h = mins / 60
        let m = mins % 60
        if h > 0 && m > 0 { return "\(h)ч \(m)мин" }
        if h > 0 { return "\(h)ч" }
        return "\(m)мин"
    }

    private var eventReminderSubtitle: String {
        let leads = eventLeadMinutes
        if leads.isEmpty { return "Нет напоминаний" }
        return leads.map { "за \(formatLead($0))" }.joined(separator: ", ")
    }

    @State private var isEventReminderExpanded = false

    private var eventReminderSection: some View {
        VStack(spacing: 0) {
            // Row: icon + text (tappable to expand) + toggle (independent)
            HStack(spacing: 12) {
                Image(systemName: "clock.fill")
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
                    Text("Напоминания о событиях")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(eventReminderSubtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    guard notifEvent else { return }
                    withAnimation(.spring(response: 0.3)) {
                        isEventReminderExpanded.toggle()
                        if !isEventReminderExpanded { isAddingReminder = false }
                    }
                }

                Spacer()

                if notifEvent && !isEventReminderExpanded {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.tertiary)
                }

                Toggle("", isOn: $notifEvent)
                    .labelsHidden()
                    .tint(AppTheme.sakuraPink)
            }
            .padding(10)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))

            // Expanded content
            if notifEvent && isEventReminderExpanded {
                VStack(spacing: 8) {
                    // Existing reminder chips
                    FlowLayout(spacing: 8) {
                        ForEach(eventLeadMinutes, id: \.self) { mins in
                            HStack(spacing: 4) {
                                Text(formatLead(mins))
                                    .font(.system(size: 12, weight: .bold))
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        removeEventLead(mins)
                                    }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .bold))
                                }
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppTheme.sakuraPink)
                            .clipShape(Capsule())
                        }

                        // Add button
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                isAddingReminder.toggle()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: isAddingReminder ? "chevron.up" : "plus")
                                    .font(.system(size: 10, weight: .bold))
                                if !isAddingReminder {
                                    Text("Добавить")
                                        .font(.system(size: 12, weight: .bold))
                                }
                            }
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                        }
                    }

                    // Timer-style picker
                    if isAddingReminder {
                        VStack(spacing: 8) {
                            HStack(spacing: 0) {
                                Picker("Часы", selection: $newReminderHours) {
                                    ForEach(0..<24, id: \.self) { h in
                                        Text("\(h) ч").tag(h)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 100, height: 100)
                                .clipped()

                                Picker("Минуты", selection: $newReminderMinutes) {
                                    ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { m in
                                        Text("\(m) мин").tag(m)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 120, height: 100)
                                .clipped()
                            }

                            Button {
                                let total = newReminderHours * 60 + newReminderMinutes
                                withAnimation(.spring(response: 0.3)) {
                                    addEventLead(total)
                                    isAddingReminder = false
                                    newReminderHours = 0
                                    newReminderMinutes = 30
                                }
                            } label: {
                                Text("Добавить")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 8)
                                    .background(AppTheme.sakuraPink)
                                    .clipShape(Capsule())
                            }
                            .disabled(newReminderHours == 0 && newReminderMinutes == 0)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(10)
                .transition(.opacity.combined(with: .move(edge: .top)))
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

    private func formatTimeMinutes(_ date: Date) -> String {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%d:%02d", comps.hour ?? 0, comps.minute ?? 0)
    }

    // MARK: - Exchange Rates Section

    private var exchangeRatesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionLabel("КУРСЫ ВАЛЮТ", icon: "arrow.left.arrow.right")
                Spacer()
                Toggle("", isOn: $useCustomRates)
                    .labelsHidden()
                    .tint(AppTheme.templeGold)
                    .scaleEffect(0.8)
                Text(useCustomRates ? "Свои" : "НКЦ")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(.tertiary)
            }

            if useCustomRates {
                ForEach(nonBaseCurrencies, id: \.self) { code in
                    customRateRow(code, binding: customRateBinding(for: code))
                }
            } else {
                compactApiRatesView
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

    private var compactApiRatesView: some View {
        let svc = CurrencyService.shared
        return VStack(spacing: 4) {
            // Compact rate grid: 2 per row
            let pairs = nonBaseCurrencies
            ForEach(0..<(pairs.count + 1) / 2, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(0..<2, id: \.self) { col in
                        let idx = row * 2 + col
                        if idx < pairs.count {
                            let code = pairs[idx]
                            let basePerUnit = svc.basePerUnit(of: code)
                            HStack(spacing: 4) {
                                Text(code)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 30, alignment: .leading)
                                Text(basePerUnit > 0 ? "\(CurrencyService.baseCurrencySymbol)\(basePerUnit < 1 ? String(format: "%.3f", basePerUnit) : String(format: "%.2f", basePerUnit))" : "—")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(AppTheme.templeGold)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            Spacer().frame(maxWidth: .infinity)
                        }
                    }
                }
            }

            // Status row
            HStack(spacing: 6) {
                if svc.isLoading {
                    ProgressView().scaleEffect(0.5)
                } else {
                    Circle()
                        .fill(svc.lastUpdated != nil ? AppTheme.bambooGreen : AppTheme.toriiRed)
                        .frame(width: 5, height: 5)
                }
                if let updated = svc.lastUpdated {
                    Text("НКЦ · \(updated, style: .relative)")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                } else if let err = svc.errorMessage {
                    Text(err)
                        .font(.system(size: 9))
                        .foregroundStyle(AppTheme.toriiRed)
                }
                Spacer()
                Button {
                    Task { await svc.fetchRates(force: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.templeGold)
                }
            }
            .padding(.top, 2)
        }
        .padding(8)
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
