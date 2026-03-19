import SwiftUI
import CoreLocation

struct WeatherDetailView: View {
    let cityName: String
    let coordinate: CLLocationCoordinate2D

    @Environment(\.dismiss) private var dismiss

    private var weather: WeatherService { WeatherService.shared }

    @State private var appeared = false
    @State private var localCurrentWeather: WeatherInfo?
    @State private var localHourly: [HourlyWeatherInfo] = []
    @State private var localDaily: [WeatherInfo] = []
    @State private var localTodayForecast: WeatherInfo?
    @State private var localAQI: AirQualityInfo?
    @State private var localAlerts: [WeatherAPIAlert] = []
    @State private var localAllHourly: [HourlyWeatherInfo] = []
    @State private var isLoadingRadar = false

    @AppStorage("notif_weather") private var notifWeather = true

    private var todayForecast: WeatherInfo? {
        localTodayForecast ?? weather.forecast(for: Date(), at: coordinate)
    }

    private var hourlyItems: [HourlyWeatherInfo] {
        localHourly.isEmpty ? weather.hourlyForecast(for: Date(), at: coordinate) : localHourly
    }

    private var upcomingForecasts: [WeatherInfo] {
        localDaily.isEmpty ? weather.upcomingForecasts(at: coordinate, count: 10) : localDaily
    }


    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: AppTheme.spacingM) {
                    // Weather alerts at top
                    if !localAlerts.isEmpty {
                        WeatherAlertBanner(alerts: localAlerts)
                    }

                    currentWeatherHeader

                    if !hourlyItems.isEmpty {
                        hourlySection
                    }

                    // AQI card (always visible)
                    aqiSection

                    precipitationMapSection

                    if !upcomingForecasts.isEmpty {
                        dailyForecastSection
                    }

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

                // 1. Show cached data immediately
                if localCurrentWeather == nil {
                    localCurrentWeather = weather.currentWeather
                }
                refreshLocalData()

                // 2. Single fetch — returns all data directly (no cache dependency)
                let detail = await weather.fetchFullDetail(for: coordinate)
                if let current = detail.current {
                    localCurrentWeather = current
                }
                if !detail.hourly.isEmpty {
                    localHourly = detail.hourly
                }
                if !detail.daily.isEmpty {
                    localDaily = detail.daily
                }
                if let today = detail.todayForecast {
                    localTodayForecast = today
                }
                if let aqi = detail.aqi {
                    localAQI = aqi
                }
                if !detail.alerts.isEmpty {
                    localAlerts = detail.alerts
                }
                if !detail.allHourly.isEmpty {
                    localAllHourly = detail.allHourly
                }

            }
        }
    }

    // MARK: - Current Weather Header + Details

    private var currentWeatherHeader: some View {
        VStack(spacing: AppTheme.spacingM) {
            // Top: city + temperature + condition
            VStack(spacing: AppTheme.spacingS) {
                HStack {
                    Spacer()
                    Text(cityName.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(.secondary)
                    Spacer()
                    // Notification toggle
                    Button {
                        notifWeather.toggle()
                    } label: {
                        Image(systemName: notifWeather ? "bell.fill" : "bell.slash")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(notifWeather ? AppTheme.sakuraPink : Color.gray.opacity(0.4))
                    }
                }

                if let current = localCurrentWeather {
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

            // Bottom: details stack
            if let today = todayForecast {
                Divider().opacity(0.1)

                VStack(spacing: 0) {
                    if let humidity = localCurrentWeather?.humidity {
                        detailRow(icon: "humidity.fill", label: "Влажность", value: "\(humidity)%", comment: humidityComment(humidity), color: AppTheme.sakuraPink)
                    }

                    if let wind = localCurrentWeather?.windSpeed {
                        detailRow(icon: "wind", label: "Ветер", value: "\(Int(wind)) км/ч", comment: windComment(wind), color: AppTheme.sakuraPink)
                    }

                    if let precip = today.precipitationProbability, precip > 0 {
                        detailRow(icon: "drop.fill", label: "Осадки", value: "\(precip)%", comment: precipComment(precip), color: AppTheme.oceanBlue)
                    }

                    if let uv = today.uvIndexMax {
                        let level = UVIndexLevel(uvIndex: uv)
                        detailRow(icon: "sun.max.fill", label: "УФ-индекс", value: "\(Int(uv)) — \(level.labelLocalized)", comment: uvComment(uv), color: level.color)
                    }

                    if let pressure = localCurrentWeather?.pressureMb {
                        detailRow(icon: "gauge.medium", label: "Давление", value: "\(Int(pressure)) мб", comment: pressureComment(pressure), color: AppTheme.oceanBlue)
                    }

                    if let visibility = localCurrentWeather?.visibilityKm {
                        detailRow(icon: "eye.fill", label: "Видимость", value: "\(Int(visibility)) км", comment: visibilityComment(visibility), color: .green)
                    }

                    if let sunrise = today.sunrise, let sunset = today.sunset {
                        detailRow(icon: "sunrise.fill", label: "Рассвет / Закат", value: "\(formatTime(sunrise)) / \(formatTime(sunset))", comment: daylightComment(sunrise: sunrise, sunset: sunset), color: .orange)
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

    private func detailRow(icon: String, label: String, value: String, comment: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(label.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(value)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                Text(comment)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.06)
        }
    }

    private func humidityComment(_ h: Int) -> String {
        if h < 30 { return "Сухой воздух, пейте больше воды" }
        if h < 60 { return "Комфортная влажность" }
        if h < 80 { return "Повышенная влажность, может быть душно" }
        return "Очень высокая влажность"
    }

    private func windComment(_ w: Double) -> String {
        if w < 5 { return "Штиль, ветра почти нет" }
        if w < 20 { return "Лёгкий ветер" }
        if w < 40 { return "Умеренный ветер, держите головной убор" }
        return "Сильный ветер, будьте осторожны"
    }

    private func precipComment(_ p: Int) -> String {
        if p < 30 { return "Маловероятны осадки" }
        if p < 60 { return "Возможен дождь, возьмите зонт на всякий случай" }
        return "Высокая вероятность, зонт обязателен"
    }

    private func uvComment(_ uv: Double) -> String {
        if uv < 3 { return "Низкий, защита не требуется" }
        if uv < 6 { return "Средний, рекомендуется солнцезащитный крем" }
        if uv < 8 { return "Высокий, крем и головной убор обязательны" }
        return "Очень высокий, избегайте прямого солнца"
    }

    private func pressureComment(_ p: Double) -> String {
        if p < 1000 { return "Пониженное, возможна усталость" }
        if p < 1020 { return "Нормальное атмосферное давление" }
        return "Повышенное давление"
    }

    private func visibilityComment(_ v: Double) -> String {
        if v < 1 { return "Очень плохая, опасно для вождения" }
        if v < 5 { return "Ограниченная, будьте внимательны" }
        return "Хорошая видимость"
    }

    private func daylightComment(sunrise: Date, sunset: Date) -> String {
        let hours = Int(sunset.timeIntervalSince(sunrise) / 3600)
        let mins = Int(sunset.timeIntervalSince(sunrise).truncatingRemainder(dividingBy: 3600) / 60)
        return "Световой день: \(hours) ч \(mins) мин"
    }

    // MARK: - Hourly Section

    private var hourlySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            GlassSectionHeader(title: "ПОЧАСОВОЙ ПРОГНОЗ", color: AppTheme.oceanBlue)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(hourlyItems) { item in
                        VStack(spacing: 5) {
                            Text(item.hourLabel)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(height: 14)

                            Text("\(Int(item.temperature))°")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                                .frame(height: 18)

                            Image(systemName: item.sfSymbol)
                                .font(.system(size: 20))
                                .symbolRenderingMode(.multicolor)
                                .frame(height: 24)

                            HStack(spacing: 2) {
                                Image(systemName: "drop.fill")
                                    .font(.system(size: 8))
                                Text("\(item.precipitationProbability ?? 0)%")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(AppTheme.oceanBlue.opacity((item.precipitationProbability ?? 0) > 0 ? 1 : 0.3))
                            .frame(height: 14)

                            Text("УФ \(Int(item.uvIndex ?? 0))")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(UVIndexLevel(uvIndex: item.uvIndex ?? 0).color.opacity((item.uvIndex ?? 0) > 0 ? 1 : 0.3))
                                .frame(height: 12)
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


    private func refreshLocalData() {
        localHourly = weather.hourlyForecast(for: Date(), at: coordinate)
        localDaily = weather.upcomingForecasts(at: coordinate, count: 10)
        localTodayForecast = weather.forecast(for: Date(), at: coordinate)
    }


    // MARK: - AQI Section (always visible)

    private var aqiSection: some View {
        Group {
            if let aqi = localAQI {
                AQICardView(aqi: aqi)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    GlassSectionHeader(title: "КАЧЕСТВО ВОЗДУХА", color: .green)

                    HStack(spacing: AppTheme.spacingS) {
                        ProgressView().scaleEffect(0.7)
                        Text("Загрузка данных...")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.spacingL)
                }
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                )
            }
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
