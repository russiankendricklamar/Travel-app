import SwiftUI
import CoreLocation

struct DashboardWeatherSection: View {
    let trip: Trip

    private var weather: WeatherService { WeatherService.shared }
    private var location: LocationManager { LocationManager.shared }

    @State private var appeared = false
    @State private var cityWeathers: [(String, WeatherInfo)] = []
    @State private var showCitiesPanel = false
    @State private var selectedCityName: String?

    private var displayedCityName: String? {
        selectedCityName ?? weatherCityName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().opacity(0.15).padding(.horizontal, AppTheme.spacingM)

            if let error = weather.errorMessage {
                errorView(error)
            } else if let current = weather.currentWeather {
                currentWeatherView(current)
            } else {
                loadingView
            }
        }
        .overlay(alignment: .trailing) {
            if showCitiesPanel {
                citiesSidePanel
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: CGFloat(AppTheme.radiusLarge)))
        .overlay(
            RoundedRectangle(cornerRadius: CGFloat(AppTheme.radiusLarge))
                .stroke(AppTheme.oceanBlue.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
        .task {
            guard !appeared else { return }
            appeared = true
            await loadWeather()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "cloud.sun.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.oceanBlue)
                VStack(alignment: .leading, spacing: 1) {
                    Text("ПОГОДА")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(AppTheme.oceanBlue)
                    if let city = displayedCityName {
                        Text(city.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            if weather.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            }
            if cityWeathers.count > 1 {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        showCitiesPanel.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("\(cityWeathers.count)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(AppTheme.oceanBlue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppTheme.oceanBlue.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(AppTheme.spacingM)
    }

    // MARK: - Current Weather

    private func currentWeatherView(_ current: WeatherInfo) -> some View {
        VStack(spacing: AppTheme.spacingS) {
            // Temperature + icon row
            HStack(alignment: .center, spacing: AppTheme.spacingM) {
                Image(systemName: current.sfSymbol)
                    .font(.system(size: 40))
                    .symbolRenderingMode(.multicolor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Int(current.temperature))°")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(current.conditionLocalized)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                    if let feels = current.apparentTemperature {
                        Text("Ощущается как \(Int(feels))°")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()
            }

            // Today min/max + UV
            todayForecastRow

            // Details row (humidity, wind)
            detailsRow(current)

            // 7-day forecast strip
            if let coord = weather.currentWeather != nil ? resolvedCoordinate : nil {
                let upcoming = weather.upcomingForecasts(at: coord)
                if !upcoming.isEmpty {
                    Divider().opacity(0.1)
                    WeatherForecastStrip(forecasts: upcoming)
                        .padding(.vertical, 4)
                }
            }

            // Recommendations
            recommendationsSection

        }
        .padding(.horizontal, AppTheme.spacingM)
        .padding(.bottom, AppTheme.spacingM)
        .padding(.top, AppTheme.spacingS)
    }

    // MARK: - Today Min/Max + UV

    private var todayForecastRow: some View {
        Group {
            if let today = weather.forecast(for: Date()),
               let max = today.temperatureMax,
               let min = today.temperatureMin {
                HStack(spacing: AppTheme.spacingM) {
                    Label("\(Int(min))°", systemImage: "arrow.down")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    Label("\(Int(max))°", systemImage: "arrow.up")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    if let precip = today.precipitationProbability, precip > 0 {
                        Label("\(precip)%", systemImage: "drop.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.oceanBlue)
                    }
                    if let uv = today.uvIndexMax {
                        uvBadge(uv)
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: - UV Badge

    private func uvBadge(_ uvIndex: Double) -> some View {
        let level = UVIndexLevel(uvIndex: uvIndex)
        return Text("УФ \(Int(uvIndex))")
            .font(.system(size: 11, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(level.color.opacity(0.2))
            .foregroundStyle(level.color)
            .clipShape(Capsule())
    }

    // MARK: - Recommendations

    private var recommendationsSection: some View {
        Group {
            let today = weather.forecast(for: Date())
            let recs = WeatherRecommendation.recommendations(
                precip: today?.precipitationProbability,
                uv: today?.uvIndexMax,
                temp: today?.temperatureMax,
                code: today?.weatherCode
            )
            if !recs.isEmpty {
                Divider().opacity(0.1)
                WeatherRecommendationsRow(recommendations: recs)
                    .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Cities Side Panel

    private var citiesSidePanel: some View {
        VStack(alignment: .trailing, spacing: 0) {
            citiesPanelCloseButton
            citiesPanelList
        }
        .frame(maxWidth: 150, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: CGFloat(AppTheme.radiusMedium),
                bottomTrailingRadius: CGFloat(AppTheme.radiusLarge),
                topTrailingRadius: CGFloat(AppTheme.radiusLarge)
            )
        )
    }

    private var citiesPanelCloseButton: some View {
        HStack {
            Spacer()
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    showCitiesPanel = false
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.tertiary)
            }
            .padding(.trailing, AppTheme.spacingM)
            .padding(.top, AppTheme.spacingS)
        }
    }

    private var citiesPanelList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: AppTheme.spacingS) {
                ForEach(cityWeathers, id: \.0) { city, info in
                    Button {
                        selectCity(city)
                    } label: {
                        CityWeatherCard(cityName: city, weather: info)
                            .overlay(
                                RoundedRectangle(cornerRadius: CGFloat(AppTheme.radiusMedium))
                                    .stroke(
                                        selectedCityName == city ? AppTheme.oceanBlue : .clear,
                                        lineWidth: 1.5
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppTheme.spacingS)
            .padding(.bottom, AppTheme.spacingM)
        }
    }

    private func selectCity(_ city: String) {
        selectedCityName = city
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            showCitiesPanel = false
        }
        Task {
            if let coord = await weather.resolveCoordinate(forCity: city) {
                await weather.fetchWeather(for: coord)
            }
        }
    }

    // MARK: - Details Row

    private func detailsRow(_ current: WeatherInfo) -> some View {
        HStack(spacing: 0) {
            if let humidity = current.humidity {
                detailItem(icon: "humidity.fill", value: "\(humidity)%")
            }
            if let wind = current.windSpeed {
                detailItem(icon: "wind", value: "\(Int(wind)) м/с")
            }
        }
    }

    private func detailItem(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: AppTheme.spacingS) {
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Button {
                Task {
                    weather.invalidateCache()
                    await loadWeather()
                }
            } label: {
                Text("Повторить")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.oceanBlue)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.spacingM)
    }

    // MARK: - Loading

    private var loadingView: some View {
        HStack(spacing: AppTheme.spacingS) {
            ProgressView()
            Text("Загрузка погоды...")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.spacingM)
    }

    // MARK: - Resolved Coordinate (for forecast strip)

    private var resolvedCoordinate: CLLocationCoordinate2D? {
        if trip.isActive, let current = location.currentLocation {
            return current
        }
        return nil
    }

    // MARK: - Load Weather

    private var weatherCityName: String? {
        if let activeDay = trip.activeDay {
            return activeDay.cityName
        }
        return trip.sortedDays.first?.cityName
    }

    private func loadWeather() async {
        let coordinate: CLLocationCoordinate2D

        if trip.isActive, let current = location.currentLocation {
            coordinate = current
        } else if let city = weatherCityName,
                  let resolved = await weather.resolveCoordinate(forCity: city) {
            coordinate = resolved
        } else if let firstPlace = trip.sortedDays.first?.places.first {
            coordinate = firstPlace.coordinate
        } else {
            return
        }

        await weather.fetchWeather(for: coordinate)

        // Multi-city: fetch weather for each unique city
        let uniqueCities = Array(Set(trip.sortedDays.map(\.cityName))).sorted()
        if uniqueCities.count > 1 {
            var results: [(String, WeatherInfo)] = []
            for city in uniqueCities {
                if let cityCoord = await weather.resolveCoordinate(forCity: city) {
                    await weather.fetchDailyForecast(for: cityCoord)
                    if let info = weather.forecast(for: Date(), at: cityCoord) {
                        results.append((city, info))
                    }
                }
            }
            cityWeathers = results
        }
    }
}
