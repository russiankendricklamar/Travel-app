import SwiftUI
import CoreLocation

struct DashboardWeatherSection: View {
    let trip: Trip

    private var weather: WeatherService { WeatherService.shared }
    private var location: LocationManager { LocationManager.shared }

    @State private var appeared = false
    @State private var cityWeathers: [(String, WeatherInfo?)] = []
    @State private var showCitiesPanel = false
    @State private var showWeatherDetail = false
    @State private var selectedCityName: String?
    @State private var fetchedCoordinate: CLLocationCoordinate2D?
    @State private var selectedCityWeather: WeatherInfo?

    private var displayedCityName: String? {
        selectedCityName ?? weatherCityName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().opacity(0.15).padding(.horizontal, AppTheme.spacingM)

            Group {
                if let error = weather.errorMessage, selectedCityWeather == nil {
                    errorView(error)
                } else if let current = selectedCityWeather ?? weather.currentWeather {
                    currentWeatherView(current)
                } else {
                    loadingView
                }
            }
            .frame(minHeight: 180)
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
        .contentShape(Rectangle())
        .onTapGesture {
            if (selectedCityWeather ?? weather.currentWeather) != nil, fetchedCoordinate != nil {
                showWeatherDetail = true
            }
        }
        .sheet(isPresented: $showWeatherDetail) {
            if let coord = fetchedCoordinate {
                WeatherDetailView(
                    cityName: displayedCityName ?? "",
                    coordinate: coord
                )
            }
        }
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
            if allTripCities.count > 1 {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        showCitiesPanel.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        let loadedCount = cityWeathers.filter { $0.1 != nil }.count
                        if let currentTemp = (selectedCityWeather ?? weather.currentWeather)?.temperature {
                            Text("\(Int(currentTemp))°")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                        }
                        Text("\(loadedCount)/\(allTripCities.count)")
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
        .padding(.horizontal, AppTheme.spacingM)
        .padding(.vertical, 10)
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

            // Details row (humidity, wind, pressure, visibility, AQI, alerts)
            detailsRow(current)

            // 7-day forecast strip (today + 6 upcoming)
            if let coord = resolvedCoordinate {
                let today = weather.forecast(for: Date(), at: coord)
                let upcoming = weather.upcomingForecasts(at: coord, count: 6)
                let allDays = [today].compactMap { $0 } + upcoming
                if !allDays.isEmpty {
                    Divider().opacity(0.1)
                    WeatherForecastStrip(forecasts: allDays)
                        .padding(.vertical, 4)
                }
            }

        }
        .padding(.horizontal, AppTheme.spacingM)
        .padding(.bottom, AppTheme.spacingM)
        .padding(.top, AppTheme.spacingS)
    }

    // MARK: - Today Min/Max + UV

    private var todayForecast: WeatherInfo? {
        if let coord = fetchedCoordinate {
            return weather.forecast(for: Date(), at: coord)
        }
        return weather.forecast(for: Date())
    }

    private var todayForecastRow: some View {
        Group {
            let today = todayForecast
            let hasMinMax = today?.temperatureMin != nil && today?.temperatureMax != nil
            let hasUV = today?.uvIndexMax != nil
            let hasPrecip = (today?.precipitationProbability ?? 0) > 0

            if hasMinMax || hasUV || hasPrecip {
                HStack(spacing: AppTheme.spacingM) {
                    if let min = today?.temperatureMin {
                        Label("\(Int(min))°", systemImage: "arrow.down")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    if let max = today?.temperatureMax {
                        Label("\(Int(max))°", systemImage: "arrow.up")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    if let precip = today?.precipitationProbability, precip > 0 {
                        Label("\(precip)%", systemImage: "drop.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.oceanBlue)
                    }
                    if let uv = today?.uvIndexMax {
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
                        if info != nil { selectCity(city) }
                    } label: {
                        if let info {
                            CityWeatherCard(cityName: city, weather: info)
                                .overlay(
                                    RoundedRectangle(cornerRadius: CGFloat(AppTheme.radiusMedium))
                                        .stroke(
                                            selectedCityName == city ? AppTheme.oceanBlue : .clear,
                                            lineWidth: 1.5
                                        )
                                )
                        } else {
                            CityWeatherCardLoading(cityName: city)
                        }
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
            // Prefer trip coordinates (instant), fall back to geocoding
            let coord: CLLocationCoordinate2D?
            if let tripCoord = coordinateFromTrip(forCity: city) {
                coord = tripCoord
            } else {
                coord = await weather.resolveCoordinate(forCity: city)
            }
            guard let coord else { return }
            fetchedCoordinate = coord
            // Single API call — fetchCurrentWeather also caches daily+hourly
            if let info = await weather.fetchCurrentWeather(for: coord) {
                selectedCityWeather = info
            }
        }
    }

    // MARK: - Details Row

    private func detailsRow(_ current: WeatherInfo) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                if let humidity = current.humidity {
                    detailItem(icon: "humidity.fill", value: "\(humidity)%")
                }
                if let wind = current.windSpeed {
                    detailItem(icon: "wind", value: "\(Int(wind)) м/с")
                }
                if let pressure = current.pressureMb {
                    detailItem(icon: "gauge.medium", value: "\(Int(pressure)) мб")
                }
                if let vis = current.visibilityKm {
                    detailItem(icon: "eye.fill", value: "\(Int(vis)) км")
                }
            }

            // AQI pill + alerts badge
            HStack(spacing: 8) {
                if let coord = fetchedCoordinate, let aqi = weather.airQuality(at: coord) {
                    HStack(spacing: 4) {
                        Image(systemName: aqi.sfSymbol)
                            .font(.system(size: 10, weight: .bold))
                        Text("AQI \(aqi.epaIndex) — \(aqi.levelLocalized)")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(aqi.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(aqi.color.opacity(0.12))
                    .clipShape(Capsule())
                }

                if let coord = fetchedCoordinate {
                    let alerts = weather.weatherAlerts(at: coord)
                    if !alerts.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 9, weight: .bold))
                            Text("\(alerts.count)")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(alerts.first?.severityColor ?? .orange)
                        .clipShape(Capsule())
                    }
                }

                Spacer()
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
    // Always use fetchedCoordinate — it matches the key under which daily data is cached
    private var resolvedCoordinate: CLLocationCoordinate2D? {
        fetchedCoordinate
    }

    // MARK: - Load Weather

    private var allTripCities: [String] {
        // Preserve trip order (first appearance), not alphabetical
        var seen = Set<String>()
        return trip.sortedDays.compactMap { day in
            let city = day.cityName
            guard !city.isEmpty, !seen.contains(city) else { return nil }
            seen.insert(city)
            return city
        }
    }

    /// Get coordinate for a city from trip places (no geocoding needed)
    private func coordinateFromTrip(forCity city: String) -> CLLocationCoordinate2D? {
        for day in trip.sortedDays where day.cityName == city {
            if let place = day.places.first {
                return place.coordinate
            }
        }
        return nil
    }

    private var weatherCityName: String? {
        if let activeDay = trip.activeDay {
            return activeDay.cityName
        }
        return trip.sortedDays.first?.cityName
    }

    private func loadWeather() async {
        let cities = allTripCities
        print("[Weather] loadWeather START cities=\(cities)")

        // Immediately show all cities with nil weather (loading state)
        if cities.count > 1 {
            cityWeathers = cities.map { ($0, nil) }
        }

        // Load weather for the primary city first (shown in main card)
        let coordinate: CLLocationCoordinate2D
        let source: String

        if trip.isActive, let current = location.currentLocation {
            coordinate = current
            source = "GPS"
        } else if let city = weatherCityName,
                  let coord = coordinateFromTrip(forCity: city) {
            coordinate = coord
            source = "tripPlace(\(city))"
        } else if let city = weatherCityName,
                  let resolved = await weather.resolveCoordinate(forCity: city) {
            coordinate = resolved
            source = "geocode(\(city))"
        } else if let firstPlace = trip.sortedDays.first?.places.first {
            coordinate = firstPlace.coordinate
            source = "firstPlace"
        } else {
            print("[Weather] loadWeather ABORT — no coordinate found")
            return
        }

        print("[Weather] primary city via \(source) lat=\(coordinate.latitude) lon=\(coordinate.longitude)")
        fetchedCoordinate = coordinate
        await weather.fetchWeather(for: coordinate)

        // Load weather for all cities in parallel
        if cities.count > 1 {
            let results = await withTaskGroup(of: (String, WeatherInfo?).self, returning: [(String, WeatherInfo?)].self) { group in
                for city in cities {
                    group.addTask {
                        let cityCoord: CLLocationCoordinate2D?
                        if let tripCoord = await self.coordinateFromTrip(forCity: city) {
                            cityCoord = tripCoord
                        } else {
                            cityCoord = await self.weather.resolveCoordinate(forCity: city)
                        }
                        guard let coord = cityCoord else {
                            print("[Weather] city '\(city)' SKIP — no coordinate")
                            return (city, nil)
                        }
                        let info = await self.weather.fetchCurrentWeather(for: coord)
                        print("[Weather] city '\(city)' \(info != nil ? "OK temp=\(Int(info!.temperature))°" : "FAILED")")
                        return (city, info)
                    }
                }
                var collected: [(String, WeatherInfo?)] = []
                for await result in group {
                    collected.append(result)
                }
                return collected
            }
            // Preserve original city order
            for city in cities {
                if let result = results.first(where: { $0.0 == city }),
                   let idx = cityWeathers.firstIndex(where: { $0.0 == city }) {
                    cityWeathers[idx] = result
                }
            }
        }
        let loaded = cityWeathers.filter { $0.1 != nil }.count
        print("[Weather] loadWeather DONE \(loaded)/\(cities.count) cities loaded")
    }
}
