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

    // Dashboard cache
    private var lastFetchDate: Date?
    private var lastFetchCoordinate: CLLocationCoordinate2D?
    private let cacheInterval: TimeInterval = 15 * 60
    private let session: URLSession

    // Sunrise/sunset time formatter
    private static let sunTimeFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return fmt
    }()

    // Hourly time formatter
    private static let hourlyFormatter: ISO8601DateFormatter = {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        return fmt
    }()

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        self.session = URLSession(configuration: config)
    }

    // Geocoded city cache (dynamic, filled at runtime)
    private var geocodedCities: [String: CLLocationCoordinate2D] = [:]

    func resolveCoordinate(forCity cityName: String) async -> CLLocationCoordinate2D? {
        let trimmed = cityName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // 1. Already geocoded
        if let cached = geocodedCities[trimmed] {
            return cached
        }

        // 2. Geocode dynamically
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.geocodeAddressString(trimmed)
            if let location = placemarks.first?.location {
                geocodedCities[trimmed] = location.coordinate
                return location.coordinate
            }
        } catch {
            // Geocoding can fail for various reasons — silently return nil
        }
        return nil
    }

    // MARK: - Location Key

    private func locationKey(_ coord: CLLocationCoordinate2D) -> String {
        let lat = (coord.latitude * 10).rounded() / 10
        let lon = (coord.longitude * 10).rounded() / 10
        return "\(lat),\(lon)"
    }

    // MARK: - Dashboard Fetch (current + daily + hourly)

    func fetchWeather(for coordinate: CLLocationCoordinate2D) async {
        if let lastDate = lastFetchDate,
           let lastCoord = lastFetchCoordinate,
           Date().timeIntervalSince(lastDate) < cacheInterval,
           abs(lastCoord.latitude - coordinate.latitude) < 0.01,
           abs(lastCoord.longitude - coordinate.longitude) < 0.01 {
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let url = buildURL(for: coordinate)
            let (data, response) = try await session.data(from: url)

            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }

            let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            parseResponse(decoded, coordinate: coordinate)

            lastFetchDate = Date()
            lastFetchCoordinate = coordinate

            // Cache for offline
            if let encoded = try? JSONEncoder().encode(decoded) {
                OfflineCacheManager.shared.cacheWeather(encoded)
            }
        } catch is DecodingError {
            errorMessage = "Ошибка данных погоды"
            restoreFromCache(coordinate: coordinate)
        } catch {
            errorMessage = "Не удалось загрузить погоду"
            restoreFromCache(coordinate: coordinate)
        }

        isLoading = false
    }

    // MARK: - Per-Location Daily Fetch

    func fetchDailyForecast(for coordinate: CLLocationCoordinate2D) async {
        let key = locationKey(coordinate)
        if let fetchDate = fetchDatesByLocation[key],
           Date().timeIntervalSince(fetchDate) < cacheInterval {
            return
        }

        do {
            let url = buildURL(for: coordinate)
            let (data, response) = try await session.data(from: url)

            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }

            let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            if let daily = decoded.daily {
                forecastsByLocation[key] = parseDailyForecasts(daily)
                fetchDatesByLocation[key] = Date()
            }
            if let hourly = decoded.hourly {
                hourlyByLocation[key] = parseHourlyForecasts(hourly)
            }
        } catch {
            // Silent fail for per-location fetches
        }
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
        // Return every 3 hours (up to 8 items)
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
              let decoded = try? JSONDecoder().decode(OpenMeteoResponse.self, from: data) else { return }
        parseResponse(decoded, coordinate: coordinate)
        errorMessage = nil
    }

    func invalidateCache() {
        lastFetchDate = nil
        lastFetchCoordinate = nil
        forecastsByLocation.removeAll()
        fetchDatesByLocation.removeAll()
        hourlyByLocation.removeAll()
    }

    // MARK: - Private

    private func buildURL(for coordinate: CLLocationCoordinate2D) -> URL {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(coordinate.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,apparent_temperature"),
            URLQueryItem(name: "hourly", value: "temperature_2m,weather_code,precipitation_probability,apparent_temperature,uv_index"),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min,weather_code,precipitation_probability_max,sunrise,sunset,uv_index_max"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "16"),
        ]
        return components.url!
    }

    private func parseResponse(_ response: OpenMeteoResponse, coordinate: CLLocationCoordinate2D) {
        if let current = response.current {
            currentWeather = WeatherInfo(
                id: "current",
                temperature: current.temperature2m,
                weatherCode: current.weatherCode,
                humidity: current.relativeHumidity2m,
                windSpeed: current.windSpeed10m,
                apparentTemperature: current.apparentTemperature
            )
        }

        let key = locationKey(coordinate)

        if let daily = response.daily {
            let forecasts = parseDailyForecasts(daily)
            forecastsByLocation[key] = forecasts
            fetchDatesByLocation[key] = Date()
        }

        if let hourly = response.hourly {
            hourlyByLocation[key] = parseHourlyForecasts(hourly)
        }
    }

    private func parseDailyForecasts(_ daily: DailyWeatherResponse) -> [WeatherInfo] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        return daily.time.enumerated().compactMap { index, dateString in
            guard index < daily.temperature2mMax.count,
                  index < daily.temperature2mMin.count,
                  index < daily.weatherCode.count,
                  index < daily.precipitationProbabilityMax.count,
                  let maxTemp = daily.temperature2mMax[index],
                  let minTemp = daily.temperature2mMin[index],
                  let code = daily.weatherCode[index] else {
                return nil
            }

            var sunriseDate: Date?
            if let sunriseStrings = daily.sunrise,
               index < sunriseStrings.count,
               let str = sunriseStrings[index] {
                sunriseDate = Self.sunTimeFormatter.date(from: str)
            }

            var sunsetDate: Date?
            if let sunsetStrings = daily.sunset,
               index < sunsetStrings.count,
               let str = sunsetStrings[index] {
                sunsetDate = Self.sunTimeFormatter.date(from: str)
            }

            var uvMax: Double?
            if let uvArray = daily.uvIndexMax,
               index < uvArray.count {
                uvMax = uvArray[index]
            }

            return WeatherInfo(
                id: dateString,
                temperature: (maxTemp + minTemp) / 2,
                temperatureMax: maxTemp,
                temperatureMin: minTemp,
                weatherCode: code,
                precipitationProbability: daily.precipitationProbabilityMax[index],
                date: dateFormatter.date(from: dateString),
                uvIndexMax: uvMax,
                sunrise: sunriseDate,
                sunset: sunsetDate
            )
        }
    }

    private func parseHourlyForecasts(_ hourly: HourlyWeatherResponse) -> [HourlyWeatherInfo] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"

        return hourly.time.enumerated().compactMap { index, timeString in
            guard index < hourly.temperature2m.count,
                  index < hourly.weatherCode.count,
                  let temp = hourly.temperature2m[index],
                  let code = hourly.weatherCode[index],
                  let date = formatter.date(from: timeString) else {
                return nil
            }

            return HourlyWeatherInfo(
                id: timeString,
                hour: date,
                temperature: temp,
                weatherCode: code,
                precipitationProbability: index < hourly.precipitationProbability.count ? hourly.precipitationProbability[index] : nil,
                apparentTemperature: index < hourly.apparentTemperature.count ? hourly.apparentTemperature[index] : nil,
                uvIndex: index < hourly.uvIndex.count ? hourly.uvIndex[index] : nil
            )
        }
    }
}
