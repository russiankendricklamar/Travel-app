import SwiftUI
import CoreLocation

struct WeatherDetailView: View {
    let cityName: String
    let coordinate: CLLocationCoordinate2D

    @Environment(\.dismiss) private var dismiss

    private var weather: WeatherService { WeatherService.shared }

    @State private var appeared = false
    @State private var aiRecommendations: [String] = []
    @State private var isLoadingAI = false
    @State private var isLoadingRadar = false

    @AppStorage("notif_weather") private var notifWeather = true
    @AppStorage("notif_weather_morning_time") private var weatherMorningMinutes = 480
    @AppStorage("notif_weather_evening_time") private var weatherEveningMinutes = 1260

    private var todayForecast: WeatherInfo? {
        weather.forecast(for: Date(), at: coordinate)
    }

    private var hourlyItems: [HourlyWeatherInfo] {
        weather.hourlyForecast(for: Date(), at: coordinate)
    }

    private var upcomingForecasts: [WeatherInfo] {
        weather.upcomingForecasts(at: coordinate, count: 10)
    }


    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: AppTheme.spacingM) {
                    currentWeatherHeader

                    if !hourlyItems.isEmpty {
                        hourlySection
                    }

                    aiRecommendationsSection

                    precipitationMapSection

                    if !upcomingForecasts.isEmpty {
                        dailyForecastSection
                    }

                    weatherNotificationSection

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.top, AppTheme.spacingS)
            }
            .sakuraGradientBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("ПОГОДА")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .tracking(3)
                        .foregroundStyle(AppTheme.oceanBlue)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .task {
                guard !appeared else { return }
                appeared = true
                await weather.fetchDailyForecast(for: coordinate)
                await loadAIRecommendations()
            }
        }
    }

    // MARK: - Current Weather Header + Details

    private var currentWeatherHeader: some View {
        VStack(spacing: AppTheme.spacingM) {
            // Top: city + temperature + condition
            VStack(spacing: AppTheme.spacingS) {
                Text(cityName.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(.secondary)

                if let current = weather.currentWeather {
                    HStack(alignment: .center, spacing: AppTheme.spacingM) {
                        Image(systemName: current.sfSymbol)
                            .font(.system(size: 52))
                            .symbolRenderingMode(.multicolor)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(Int(current.temperature))°")
                                .font(.system(size: 46, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)

                            Text(current.conditionLocalized)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.secondary)

                            HStack(spacing: AppTheme.spacingS) {
                                if let feels = current.apparentTemperature {
                                    Text("Ощущается \(Int(feels))°")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.tertiary)
                                }
                                if let today = todayForecast,
                                   let min = today.temperatureMin,
                                   let max = today.temperatureMax {
                                    Text("↓\(Int(min))° ↑\(Int(max))°")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 4)
                } else {
                    ProgressView()
                    Text("Загрузка...")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }

            // Bottom: details grid
            if let today = todayForecast {
                Divider().opacity(0.1)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 10) {
                    if let humidity = weather.currentWeather?.humidity {
                        detailCard(icon: "humidity.fill", label: "Влажность", value: "\(humidity)%", color: AppTheme.sakuraPink)
                    }

                    if let wind = weather.currentWeather?.windSpeed {
                        detailCard(icon: "wind", label: "Ветер", value: "\(Int(wind)) м/с", color: AppTheme.sakuraPink)
                    }

                    if let precip = today.precipitationProbability, precip > 0 {
                        detailCard(icon: "drop.fill", label: "Осадки", value: "\(precip)%", color: AppTheme.sakuraPink)
                    }

                    if let uv = today.uvIndexMax {
                        let level = UVIndexLevel(uvIndex: uv)
                        detailCard(icon: "sun.max.fill", label: "УФ-индекс", value: "\(Int(uv)) — \(level.labelLocalized)", color: level.color)
                    }

                    if let sunrise = today.sunrise {
                        detailCard(icon: "sunrise.fill", label: "Рассвет", value: formatTime(sunrise), color: .orange)
                    }

                    if let sunset = today.sunset {
                        detailCard(icon: "sunset.fill", label: "Закат", value: formatTime(sunset), color: AppTheme.indigoPurple)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(AppTheme.oceanBlue.opacity(0.15), lineWidth: 0.5)
        )
    }

    private func detailCard(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)

            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
    }

    // MARK: - Hourly Section

    private var hourlySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            GlassSectionHeader(title: "ПОЧАСОВОЙ ПРОГНОЗ", color: AppTheme.oceanBlue)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(hourlyItems) { item in
                        VStack(spacing: 6) {
                            Text(item.hourLabel)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)

                            Image(systemName: item.sfSymbol)
                                .font(.system(size: 20))
                                .symbolRenderingMode(.multicolor)

                            Text("\(Int(item.temperature))°")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)

                            if let feels = item.apparentTemperature {
                                Text("\(Int(feels))°")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.tertiary)
                            }

                            if let precip = item.precipitationProbability, precip > 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: "drop.fill")
                                        .font(.system(size: 8))
                                    Text("\(precip)%")
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .foregroundStyle(AppTheme.oceanBlue)
                            }

                            if let uv = item.uvIndex, uv > 0 {
                                Text("УФ \(Int(uv))")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(UVIndexLevel(uvIndex: uv).color)
                            }
                        }
                        .frame(width: 56)
                        .padding(.vertical, 10)
                    }
                }
                .padding(.horizontal, AppTheme.spacingM)
            }
            .padding(.bottom, AppTheme.spacingS)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - AI Recommendations

    private var aiRecommendationsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                GlassSectionHeader(title: "РЕКОМЕНДАЦИИ", color: AppTheme.templeGold)
                Spacer()
                if !isLoadingAI && !aiRecommendations.isEmpty {
                    Button {
                        Task { await loadAIRecommendations() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppTheme.templeGold)
                    }
                    .padding(.trailing, AppTheme.spacingM)
                }
            }

            if isLoadingAI {
                HStack(spacing: AppTheme.spacingS) {
                    ProgressView().scaleEffect(0.7)
                    Text("Анализирую погоду...")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, AppTheme.spacingM)
            } else if aiRecommendations.isEmpty {
                Text("Не удалось получить рекомендации")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, AppTheme.spacingM)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(aiRecommendations.enumerated()), id: \.offset) { _, text in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(AppTheme.templeGold)
                                .frame(width: 20)
                                .padding(.top, 1)

                            Text(text)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.bottom, AppTheme.spacingM)
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
    }

    private func loadAIRecommendations() async {
        guard let current = weather.currentWeather else { return }
        isLoadingAI = true
        defer { isLoadingAI = false }

        let today = todayForecast
        var context = "Город: \(cityName). "
        context += "Сейчас: \(current.conditionLocalized), \(Int(current.temperature))°C. "
        if let feels = current.apparentTemperature {
            context += "Ощущается как \(Int(feels))°. "
        }
        if let humidity = current.humidity { context += "Влажность: \(humidity)%. " }
        if let wind = current.windSpeed { context += "Ветер: \(Int(wind)) м/с. " }
        if let min = today?.temperatureMin, let max = today?.temperatureMax {
            context += "Мин/макс за день: \(Int(min))°/\(Int(max))°. "
        }
        if let precip = today?.precipitationProbability, precip > 0 {
            context += "Вероятность осадков: \(precip)%. "
        }
        if let uv = today?.uvIndexMax { context += "УФ-индекс: \(Int(uv)). " }

        let profileCtx = AIPromptHelper.profileContext()

        let prompt = """
        \(context)
        \(profileCtx)

        Дай 4-5 коротких практических рекомендаций для туриста на сегодня, СТРОГО привязанных к этой погоде.
        Каждая рекомендация должна объяснять ПОЧЕМУ именно из-за погоды: что надеть, нужен ли зонт/крем от солнца, какие активности подходят (открытые/закрытые), стоит ли гулять утром или вечером.
        НЕ рекомендуй конкретные магазины, рестораны или достопримечательности — только советы по погоде и одежде.
        Каждая рекомендация — одно предложение. Без нумерации. Каждая на новой строке. Русский язык.
        """

        if let text = await GeminiService.shared.rawRequest(prompt: prompt) {
            aiRecommendations = text
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .map { line in
                    var clean = line
                    // Strip leading bullets/dashes/numbers
                    while let first = clean.first, "•·—–-*0123456789.)  ".contains(first) {
                        clean.removeFirst()
                    }
                    return clean.trimmingCharacters(in: .whitespaces)
                }
                .filter { !$0.isEmpty }
        }
    }

    // MARK: - Precipitation Map

    private var precipitationMapSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                GlassSectionHeader(title: "КАРТА ОСАДКОВ", color: AppTheme.oceanBlue)
                Spacer()
                if isLoadingRadar {
                    ProgressView().scaleEffect(0.6)
                        .padding(.trailing, AppTheme.spacingM)
                }
            }

            PrecipitationMapView(coordinate: coordinate, isLoading: $isLoadingRadar)
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.bottom, AppTheme.spacingM)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - Daily Forecast

    private static let dayNames: [String] = [
        String(localized: "Воскресенье"),
        String(localized: "Понедельник"),
        String(localized: "Вторник"),
        String(localized: "Среда"),
        String(localized: "Четверг"),
        String(localized: "Пятница"),
        String(localized: "Суббота")
    ]

    private var dailyForecastSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            GlassSectionHeader(title: "ПРОГНОЗ НА \(upcomingForecasts.count) ДНЕЙ", color: AppTheme.oceanBlue)

            VStack(spacing: 0) {
                ForEach(Array(upcomingForecasts.enumerated()), id: \.element.id) { index, info in
                    dailyRow(info)

                    if index < upcomingForecasts.count - 1 {
                        Divider().opacity(0.08).padding(.horizontal, AppTheme.spacingM)
                    }
                }
            }
            .padding(.bottom, AppTheme.spacingS)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
    }

    private func dailyRow(_ info: WeatherInfo) -> some View {
        HStack(spacing: 0) {
            // Day name + date
            if let date = info.date {
                VStack(alignment: .leading, spacing: 1) {
                    Text(Self.dayNames[Calendar.current.component(.weekday, from: date) - 1])
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)
                    Text(formatDate(date))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .frame(width: 110, alignment: .leading)
            }

            // Icon
            Image(systemName: info.sfSymbol)
                .font(.system(size: 18))
                .symbolRenderingMode(.multicolor)
                .frame(width: 30)

            // Precip
            if let precip = info.precipitationProbability, precip > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 9))
                    Text("\(precip)%")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(AppTheme.oceanBlue)
                .frame(width: 44, alignment: .leading)
            } else {
                Spacer().frame(width: 44)
            }

            Spacer()

            // Min temp
            if let min = info.temperatureMin {
                Text("\(Int(min))°")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .frame(width: 32, alignment: .trailing)
            }

            // Temperature bar
            temperatureBar(info)
                .frame(width: 50)
                .padding(.horizontal, 6)

            // Max temp
            if let max = info.temperatureMax {
                Text("\(Int(max))°")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .frame(width: 32, alignment: .leading)
            }
        }
        .padding(.horizontal, AppTheme.spacingM)
        .padding(.vertical, 10)
    }

    private func temperatureBar(_ info: WeatherInfo) -> some View {
        GeometryReader { geo in
            let allMin = upcomingForecasts.compactMap(\.temperatureMin).min() ?? 0
            let allMax = upcomingForecasts.compactMap(\.temperatureMax).max() ?? 40
            let range = max(allMax - allMin, 1)

            let lo = ((info.temperatureMin ?? allMin) - allMin) / range
            let hi = ((info.temperatureMax ?? allMax) - allMin) / range

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 4)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.oceanBlue, AppTheme.templeGold],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: max(geo.size.width * (hi - lo), 4),
                        height: 4
                    )
                    .offset(x: geo.size.width * lo)
            }
            .frame(height: geo.size.height)
        }
        .frame(height: 4)
    }

    // MARK: - Weather Notification Settings

    private var weatherMorningTime: Binding<Date> {
        Binding<Date>(
            get: {
                let h = weatherMorningMinutes / 60
                let m = weatherMorningMinutes % 60
                return Calendar.current.date(from: DateComponents(hour: h, minute: m)) ?? Date()
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                weatherMorningMinutes = (comps.hour ?? 8) * 60 + (comps.minute ?? 0)
            }
        )
    }

    private var weatherEveningTime: Binding<Date> {
        Binding<Date>(
            get: {
                let h = weatherEveningMinutes / 60
                let m = weatherEveningMinutes % 60
                return Calendar.current.date(from: DateComponents(hour: h, minute: m)) ?? Date()
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                weatherEveningMinutes = (comps.hour ?? 21) * 60 + (comps.minute ?? 0)
            }
        )
    }

    private var weatherNotificationSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            GlassSectionHeader(title: "УВЕДОМЛЕНИЯ", color: AppTheme.oceanBlue)

            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "cloud.sun.fill")
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
                        Text("Прогноз погоды")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text("Утром и вечером")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: $notifWeather)
                        .labelsHidden()
                        .tint(AppTheme.sakuraPink)
                }

                if notifWeather {
                    VStack(spacing: 6) {
                        HStack {
                            Text("Утро")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            DatePicker("", selection: weatherMorningTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .tint(AppTheme.oceanBlue)
                        }
                        HStack {
                            Text("Вечер")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            DatePicker("", selection: weatherEveningTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .tint(AppTheme.oceanBlue)
                        }
                    }
                    .padding(.leading, 46)
                }
            }
            .padding(AppTheme.spacingM)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - Helpers

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
}
