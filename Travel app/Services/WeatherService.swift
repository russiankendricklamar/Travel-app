import Foundation
import CoreLocation

@MainActor @Observable
final class WeatherService {
    static let shared = WeatherService()

    // Dashboard state (single location)
    var currentWeather: WeatherInfo?
    var isLoading = false
    var errorMessage: String?

    // Per-location daily forecast cache
    private var forecastsByLocation: [String: [WeatherInfo]] = [:]
    private var fetchDatesByLocation: [String: Date] = [:]

    // Per-location hourly forecast cache
    private var hourlyByLocation: [String: [HourlyWeatherInfo]] = [:]

    // Per-location current weather cache
    private var currentByLocation: [String: WeatherInfo] = [:]

    // Per-location AQI and alerts cache
    private var aqiByLocation: [String: AirQualityInfo] = [:]
    private var alertsByLocation: [String: [WeatherAPIAlert]] = [:]

    // Dashboard cache
    private var lastFetchDate: Date?
    private var lastFetchCoordinate: CLLocationCoordinate2D?
    private let cacheInterval: TimeInterval = 15 * 60

    private init() {}

    // Geocoded city cache (dynamic, filled at runtime)
    private var geocodedCities: [String: CLLocationCoordinate2D] = [:]

    func resolveCoordinate(forCity cityName: String) async -> CLLocationCoordinate2D? {
        let trimmed = cityName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        if let cached = geocodedCities[trimmed] {
            return cached
        }

        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.geocodeAddressString(trimmed)
            if let location = placemarks.first?.location {
                geocodedCities[trimmed] = location.coordinate
                return location.coordinate
            }
        } catch {}
        return nil
    }

    // MARK: - Location Key

    private func locationKey(_ coord: CLLocationCoordinate2D) -> String {
        let lat = (coord.latitude * 100).rounded() / 100
        let lon = (coord.longitude * 100).rounded() / 100
        return "\(lat),\(lon)"
    }

    // MARK: - Dashboard Fetch (current + daily + hourly)

    func fetchWeather(for coordinate: CLLocationCoordinate2D) async {
        let key = locationKey(coordinate)
        if let lastDate = lastFetchDate,
           let lastCoord = lastFetchCoordinate,
           Date().timeIntervalSince(lastDate) < cacheInterval,
           abs(lastCoord.latitude - coordinate.latitude) < 0.01,
           abs(lastCoord.longitude - coordinate.longitude) < 0.01 {
            print("[Weather] fetchWeather CACHED key=\(key)")
            return
        }

        print("[Weather] fetchWeather START key=\(key)")
        isLoading = true
        errorMessage = nil

        do {
            let data = try await SupabaseProxy.request(service: "weather", action: "forecast", params: weatherParams(for: coordinate))
            print("[Weather] fetchWeather GOT \(data.count) bytes")

            let decoded = try JSONDecoder().decode(WeatherAPIResponse.self, from: data)

            lastFetchDate = Date()
            lastFetchCoordinate = coordinate

            parseResponse(decoded, coordinate: coordinate)
            print("[Weather] fetchWeather OK current=\(currentWeather?.temperature ?? -999)° daily=\(forecastsByLocation[key]?.count ?? 0) hourly=\(hourlyByLocation[key]?.count ?? 0)")

            if let encoded = try? JSONEncoder().encode(decoded) {
                OfflineCacheManager.shared.cacheWeather(encoded)
            }
        } catch is DecodingError {
            print("[Weather] fetchWeather DECODE ERROR key=\(key)")
            errorMessage = "Ошибка данных погоды"
            restoreFromCache(coordinate: coordinate)
        } catch {
            print("[Weather] fetchWeather ERROR key=\(key): \(error.localizedDescription)")
            errorMessage = "Не удалось загрузить погоду"
            restoreFromCache(coordinate: coordinate)
        }

        isLoading = false
    }

    // MARK: - Per-Location Current Weather (no global state mutation)

    func fetchCurrentWeather(for coordinate: CLLocationCoordinate2D, skipCache: Bool = false) async -> WeatherInfo? {
        let key = locationKey(coordinate)

        if !skipCache,
           let cached = currentByLocation[key],
           let fetchDate = fetchDatesByLocation[key],
           Date().timeIntervalSince(fetchDate) < cacheInterval {
            print("[Weather] fetchCurrent CACHED key=\(key)")
            return cached
        }

        print("[Weather] fetchCurrent START key=\(key)")
        do {
            let data = try await SupabaseProxy.request(service: "weather", action: "forecast", params: weatherParams(for: coordinate))
            print("[Weather] fetchCurrent GOT \(data.count) bytes key=\(key)")
            let decoded = try JSONDecoder().decode(WeatherAPIResponse.self, from: data)

            if let forecast = decoded.forecast {
                let (daily, hourly) = parseForecastDays(forecast.forecastday)
                forecastsByLocation[key] = daily
                hourlyByLocation[key] = hourly
                fetchDatesByLocation[key] = Date()
            }

            if let current = decoded.current {
                let info = WeatherInfo(
                    id: "current-\(key)",
                    temperature: current.tempC,
                    weatherCode: current.condition.code,
                    humidity: current.humidity,
                    windSpeed: current.windKph,
                    apparentTemperature: current.feelslikeC,
                    pressureMb: current.pressureMb,
                    visibilityKm: current.visKm
                )
                currentByLocation[key] = info

                if let aq = current.airQuality, let epa = aq.usEpaIndex {
                    aqiByLocation[key] = AirQualityInfo(epaIndex: epa, pm25: aq.pm2_5 ?? 0, pm10: aq.pm10 ?? 0)
                }

                return info
            }
            print("[Weather] fetchCurrent NO CURRENT DATA key=\(key)")
        } catch {
            print("[Weather] fetchCurrent ERROR key=\(key): \(error.localizedDescription)")
        }
        return nil
    }

    // MARK: - Per-Location Daily Fetch

    func fetchDailyForecast(for coordinate: CLLocationCoordinate2D) async {
        let key = locationKey(coordinate)
        if let fetchDate = fetchDatesByLocation[key],
           Date().timeIntervalSince(fetchDate) < cacheInterval {
            return
        }

        do {
            let data = try await SupabaseProxy.request(service: "weather", action: "forecast", params: weatherParams(for: coordinate))
            let decoded = try JSONDecoder().decode(WeatherAPIResponse.self, from: data)
            if let forecast = decoded.forecast {
                let (daily, hourly) = parseForecastDays(forecast.forecastday)
                forecastsByLocation[key] = daily
                hourlyByLocation[key] = hourly
                fetchDatesByLocation[key] = Date()
            }
        } catch {}
    }

    // MARK: - Full Detail Fetch (returns all data directly)

    struct WeatherDetailData {
        var current: WeatherInfo?
        var hourly: [HourlyWeatherInfo]
        var daily: [WeatherInfo]
        var todayForecast: WeatherInfo?
        var aqi: AirQualityInfo?
        var alerts: [WeatherAPIAlert] = []
        var allHourly: [HourlyWeatherInfo] = []
    }

    func fetchFullDetail(for coordinate: CLLocationCoordinate2D) async -> WeatherDetailData {
        let key = locationKey(coordinate)
        print("[Weather] fetchFullDetail START key=\(key)")

        do {
            let data = try await SupabaseProxy.request(service: "weather", action: "forecast", params: weatherParams(for: coordinate))
            print("[Weather] fetchFullDetail GOT \(data.count) bytes")
            let decoded = try JSONDecoder().decode(WeatherAPIResponse.self, from: data)

            var result = WeatherDetailData(current: nil, hourly: [], daily: [], todayForecast: nil, aqi: nil, alerts: [], allHourly: [])

            if let current = decoded.current {
                result.current = WeatherInfo(
                    id: "current-\(key)",
                    temperature: current.tempC,
                    weatherCode: current.condition.code,
                    humidity: current.humidity,
                    windSpeed: current.windKph,
                    apparentTemperature: current.feelslikeC,
                    pressureMb: current.pressureMb,
                    visibilityKm: current.visKm
                )
                currentByLocation[key] = result.current

                if let aq = current.airQuality, let epa = aq.usEpaIndex {
                    let aqiInfo = AirQualityInfo(epaIndex: epa, pm25: aq.pm2_5 ?? 0, pm10: aq.pm10 ?? 0)
                    aqiByLocation[key] = aqiInfo
                    result.aqi = aqiInfo
                }
            }

            if let alerts = decoded.alerts?.alert, !alerts.isEmpty {
                alertsByLocation[key] = alerts
                result.alerts = alerts
            }

            if let forecast = decoded.forecast {
                let (daily, hourly) = parseForecastDays(forecast.forecastday)
                forecastsByLocation[key] = daily
                hourlyByLocation[key] = hourly
                fetchDatesByLocation[key] = Date()

                result.allHourly = hourly

                let calendar = Calendar.current
                result.todayForecast = daily.first { info in
                    guard let d = info.date else { return false }
                    return calendar.isDate(d, inSameDayAs: Date())
                }

                let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
                result.daily = Array(daily.filter { info in
                    guard let d = info.date else { return false }
                    return d >= tomorrow
                }.prefix(10))

                // Hourly for today
                let todayHourly = hourly.filter { calendar.isDate($0.hour, inSameDayAs: Date()) }
                result.hourly = stride(from: 0, to: todayHourly.count, by: 3).compactMap { i in
                    i < todayHourly.count ? todayHourly[i] : nil
                }
            }

            print("[Weather] fetchFullDetail OK current=\(result.current != nil) hourly=\(result.hourly.count) daily=\(result.daily.count) aqi=\(result.aqi != nil) alerts=\(result.alerts.count)")
            return result
        } catch {
            print("[Weather] fetchFullDetail ERROR key=\(key): \(error.localizedDescription)")
        }

        return WeatherDetailData(
            current: currentByLocation[key],
            hourly: hourlyForecast(for: Date(), at: coordinate),
            daily: upcomingForecasts(at: coordinate, count: 10),
            todayForecast: forecast(for: Date(), at: coordinate)
        )
    }

    // MARK: - Forecast Accessors

    func forecast(for date: Date) -> WeatherInfo? {
        guard let coord = lastFetchCoordinate else { return nil }
        return forecast(for: date, at: coord)
    }

    func forecast(for date: Date, at coordinate: CLLocationCoordinate2D) -> WeatherInfo? {
        let key = locationKey(coordinate)
        guard let forecasts = forecastsByLocation[key] else { return nil }
        let calendar = Calendar.current
        return forecasts.first { info in
            guard let infoDate = info.date else { return false }
            return calendar.isDate(infoDate, inSameDayAs: date)
        }
    }

    func hourlyForecast(for date: Date, at coordinate: CLLocationCoordinate2D) -> [HourlyWeatherInfo] {
        let key = locationKey(coordinate)
        guard let allHourly = hourlyByLocation[key] else { return [] }
        let calendar = Calendar.current
        let dayItems = allHourly.filter { calendar.isDate($0.hour, inSameDayAs: date) }
        return stride(from: 0, to: dayItems.count, by: 3).compactMap { i in
            i < dayItems.count ? dayItems[i] : nil
        }
    }

    func upcomingForecasts(at coordinate: CLLocationCoordinate2D, count: Int = 7) -> [WeatherInfo] {
        let key = locationKey(coordinate)
        guard let forecasts = forecastsByLocation[key] else { return [] }
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        return Array(
            forecasts
                .filter { info in
                    guard let d = info.date else { return false }
                    return d >= tomorrow
                }
                .prefix(count)
        )
    }

    func notificationSummary(for date: Date) -> String? {
        guard let forecast = forecast(for: date) else { return nil }
        var parts: [String] = []
        parts.append(forecast.conditionLocalized)
        if let max = forecast.temperatureMax, let min = forecast.temperatureMin {
            parts.append("\(Int(min))...\(Int(max))°C")
        }
        if let precip = forecast.precipitationProbability, precip > 0 {
            parts.append("Осадки: \(precip)%")
        }
        return parts.joined(separator: ", ")
    }

    private func restoreFromCache(coordinate: CLLocationCoordinate2D) {
        guard let data = OfflineCacheManager.shared.cachedWeather(),
              let decoded = try? JSONDecoder().decode(WeatherAPIResponse.self, from: data) else { return }
        lastFetchCoordinate = coordinate
        lastFetchDate = Date()
        parseResponse(decoded, coordinate: coordinate)
        errorMessage = nil
    }

    func airQuality(at coordinate: CLLocationCoordinate2D) -> AirQualityInfo? {
        aqiByLocation[locationKey(coordinate)]
    }

    func weatherAlerts(at coordinate: CLLocationCoordinate2D) -> [WeatherAPIAlert] {
        alertsByLocation[locationKey(coordinate)] ?? []
    }

    func allHourlyData(at coordinate: CLLocationCoordinate2D) -> [HourlyWeatherInfo] {
        hourlyByLocation[locationKey(coordinate)] ?? []
    }

    func invalidateCache() {
        lastFetchDate = nil
        lastFetchCoordinate = nil
        forecastsByLocation.removeAll()
        fetchDatesByLocation.removeAll()
        hourlyByLocation.removeAll()
        currentByLocation.removeAll()
        aqiByLocation.removeAll()
        alertsByLocation.removeAll()
    }

    // MARK: - Private

    private func weatherParams(for coordinate: CLLocationCoordinate2D) -> [String: String] {
        [
            "q": "\(coordinate.latitude),\(coordinate.longitude)",
            "days": "7",
            "aqi": "yes",
            "alerts": "yes"
        ]
    }

    private func parseResponse(_ response: WeatherAPIResponse, coordinate: CLLocationCoordinate2D) {
        let key = locationKey(coordinate)

        if let current = response.current {
            currentWeather = WeatherInfo(
                id: "current",
                temperature: current.tempC,
                weatherCode: current.condition.code,
                humidity: current.humidity,
                windSpeed: current.windKph,
                apparentTemperature: current.feelslikeC,
                pressureMb: current.pressureMb,
                visibilityKm: current.visKm
            )

            if let aq = current.airQuality, let epa = aq.usEpaIndex {
                aqiByLocation[key] = AirQualityInfo(
                    epaIndex: epa,
                    pm25: aq.pm2_5 ?? 0,
                    pm10: aq.pm10 ?? 0
                )
            }
        }

        if let alerts = response.alerts?.alert, !alerts.isEmpty {
            alertsByLocation[key] = alerts
        }

        if let forecast = response.forecast {
            let (daily, hourly) = parseForecastDays(forecast.forecastday)
            forecastsByLocation[key] = daily
            hourlyByLocation[key] = hourly
            fetchDatesByLocation[key] = Date()
        }
    }

    private func parseForecastDays(_ days: [WeatherAPIForecastDay]) -> ([WeatherInfo], [HourlyWeatherInfo]) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let hourFormatter = DateFormatter()
        hourFormatter.dateFormat = "yyyy-MM-dd HH:mm"

        // Sunrise/sunset: "06:45 AM" format — need date context
        let sunTimeFormatter = DateFormatter()
        sunTimeFormatter.dateFormat = "hh:mm a"
        sunTimeFormatter.locale = Locale(identifier: "en_US_POSIX")

        var allDaily: [WeatherInfo] = []
        var allHourly: [HourlyWeatherInfo] = []

        for forecastDay in days {
            let dayDate = dateFormatter.date(from: forecastDay.date)

            // Parse sunrise/sunset with date context
            var sunriseDate: Date?
            var sunsetDate: Date?
            if let dayDate {
                let calendar = Calendar.current
                if let sunriseStr = forecastDay.astro.sunrise,
                   let sunriseTime = sunTimeFormatter.date(from: sunriseStr) {
                    let comps = calendar.dateComponents([.hour, .minute], from: sunriseTime)
                    sunriseDate = calendar.date(bySettingHour: comps.hour ?? 6, minute: comps.minute ?? 0, second: 0, of: dayDate)
                }
                if let sunsetStr = forecastDay.astro.sunset,
                   let sunsetTime = sunTimeFormatter.date(from: sunsetStr) {
                    let comps = calendar.dateComponents([.hour, .minute], from: sunsetTime)
                    sunsetDate = calendar.date(bySettingHour: comps.hour ?? 18, minute: comps.minute ?? 0, second: 0, of: dayDate)
                }
            }

            let precipChance = max(
                forecastDay.day.dailyChanceOfRain?.intValue ?? 0,
                forecastDay.day.dailyChanceOfSnow?.intValue ?? 0
            )

            let info = WeatherInfo(
                id: forecastDay.date,
                temperature: (forecastDay.day.maxtempC + forecastDay.day.mintempC) / 2,
                temperatureMax: forecastDay.day.maxtempC,
                temperatureMin: forecastDay.day.mintempC,
                weatherCode: forecastDay.day.condition.code,
                precipitationProbability: precipChance,
                date: dayDate,
                uvIndexMax: forecastDay.day.uv,
                sunrise: sunriseDate,
                sunset: sunsetDate
            )
            allDaily.append(info)

            // Parse hourly
            for hourData in forecastDay.hour {
                guard let hourDate = hourFormatter.date(from: hourData.time) else { continue }

                let hourPrecip = max(
                    hourData.chanceOfRain?.intValue ?? 0,
                    hourData.chanceOfSnow?.intValue ?? 0
                )

                let hourInfo = HourlyWeatherInfo(
                    id: hourData.time,
                    hour: hourDate,
                    temperature: hourData.tempC,
                    weatherCode: hourData.condition.code,
                    precipitationProbability: hourPrecip,
                    apparentTemperature: hourData.feelslikeC,
                    uvIndex: hourData.uv
                )
                allHourly.append(hourInfo)
            }
        }

        return (allDaily, allHourly)
    }
}
