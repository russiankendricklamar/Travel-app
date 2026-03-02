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

    // Dashboard cache
    private var lastFetchDate: Date?
    private var lastFetchCoordinate: CLLocationCoordinate2D?
    private let cacheInterval: TimeInterval = 15 * 60
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        self.session = URLSession(configuration: config)
    }

    // MARK: - Japanese City Coordinates

    static let japaneseCities: [String: CLLocationCoordinate2D] = [
        "Токио": CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671),
        "Tokyo": CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671),
        "Киото": CLLocationCoordinate2D(latitude: 35.0116, longitude: 135.7681),
        "Kyoto": CLLocationCoordinate2D(latitude: 35.0116, longitude: 135.7681),
        "Осака": CLLocationCoordinate2D(latitude: 34.6937, longitude: 135.5023),
        "Osaka": CLLocationCoordinate2D(latitude: 34.6937, longitude: 135.5023),
        "Камакура": CLLocationCoordinate2D(latitude: 35.3192, longitude: 139.5467),
        "Kamakura": CLLocationCoordinate2D(latitude: 35.3192, longitude: 139.5467),
        "Нара": CLLocationCoordinate2D(latitude: 34.6851, longitude: 135.8050),
        "Nara": CLLocationCoordinate2D(latitude: 34.6851, longitude: 135.8050),
        "Хиросима": CLLocationCoordinate2D(latitude: 34.3853, longitude: 132.4553),
        "Hiroshima": CLLocationCoordinate2D(latitude: 34.3853, longitude: 132.4553),
        "Сузука": CLLocationCoordinate2D(latitude: 34.8824, longitude: 136.5843),
        "Suzuka": CLLocationCoordinate2D(latitude: 34.8824, longitude: 136.5843),
        "Нагоя": CLLocationCoordinate2D(latitude: 35.1815, longitude: 136.9066),
        "Nagoya": CLLocationCoordinate2D(latitude: 35.1815, longitude: 136.9066),
        "Никко": CLLocationCoordinate2D(latitude: 36.7199, longitude: 139.6982),
        "Nikko": CLLocationCoordinate2D(latitude: 36.7199, longitude: 139.6982),
        "Кобе": CLLocationCoordinate2D(latitude: 34.6901, longitude: 135.1956),
        "Kobe": CLLocationCoordinate2D(latitude: 34.6901, longitude: 135.1956),
        "Йокогама": CLLocationCoordinate2D(latitude: 35.4437, longitude: 139.6380),
        "Yokohama": CLLocationCoordinate2D(latitude: 35.4437, longitude: 139.6380),
        "Саппоро": CLLocationCoordinate2D(latitude: 43.0618, longitude: 141.3545),
        "Sapporo": CLLocationCoordinate2D(latitude: 43.0618, longitude: 141.3545),
        "Фукуока": CLLocationCoordinate2D(latitude: 33.5904, longitude: 130.4017),
        "Fukuoka": CLLocationCoordinate2D(latitude: 33.5904, longitude: 130.4017),
        "Хакодатэ": CLLocationCoordinate2D(latitude: 41.7687, longitude: 140.7290),
        "Hakodate": CLLocationCoordinate2D(latitude: 41.7687, longitude: 140.7290),
        "Такаяма": CLLocationCoordinate2D(latitude: 36.1461, longitude: 137.2522),
        "Takayama": CLLocationCoordinate2D(latitude: 36.1461, longitude: 137.2522),
        "Канадзава": CLLocationCoordinate2D(latitude: 36.5613, longitude: 136.6562),
        "Kanazawa": CLLocationCoordinate2D(latitude: 36.5613, longitude: 136.6562),
    ]

    // Geocoded city cache (dynamic, filled at runtime)
    private var geocodedCities: [String: CLLocationCoordinate2D] = [:]

    static func coordinate(forCity cityName: String) -> CLLocationCoordinate2D? {
        japaneseCities[cityName]
    }

    func resolveCoordinate(forCity cityName: String) async -> CLLocationCoordinate2D? {
        let trimmed = cityName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // 1. Hardcoded table
        if let coord = Self.japaneseCities[trimmed] {
            return coord
        }

        // 2. Already geocoded
        if let cached = geocodedCities[trimmed] {
            return cached
        }

        // 3. Geocode dynamically
        let geocoder = CLGeocoder()
        let queries = [trimmed, "\(trimmed), Japan"]
        for query in queries {
            do {
                let placemarks = try await geocoder.geocodeAddressString(query)
                if let location = placemarks.first?.location {
                    geocodedCities[trimmed] = location.coordinate
                    return location.coordinate
                }
            } catch {
                continue
            }
        }
        return nil
    }

    // MARK: - Location Key

    private func locationKey(_ coord: CLLocationCoordinate2D) -> String {
        let lat = (coord.latitude * 10).rounded() / 10
        let lon = (coord.longitude * 10).rounded() / 10
        return "\(lat),\(lon)"
    }

    // MARK: - Dashboard Fetch (current + daily)

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
        } catch let decodingError as DecodingError {
            print("Weather decode error: \(decodingError)")
            errorMessage = "Ошибка данных погоды"
        } catch {
            print("Weather fetch error: \(error)")
            errorMessage = "Не удалось загрузить погоду"
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
        } catch {
            print("Weather daily fetch error for \(key): \(error)")
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

    func notificationSummary(for date: Date) -> String? {
        guard let forecast = forecast(for: date) else { return nil }
        var parts: [String] = []
        parts.append(forecast.conditionRussian)
        if let max = forecast.temperatureMax, let min = forecast.temperatureMin {
            parts.append("\(Int(min))...\(Int(max))°C")
        }
        if let precip = forecast.precipitationProbability, precip > 0 {
            parts.append("Осадки: \(precip)%")
        }
        return parts.joined(separator: ", ")
    }

    func invalidateCache() {
        lastFetchDate = nil
        lastFetchCoordinate = nil
        forecastsByLocation.removeAll()
        fetchDatesByLocation.removeAll()
    }

    // MARK: - Private

    private func buildURL(for coordinate: CLLocationCoordinate2D) -> URL {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(coordinate.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m"),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min,weather_code,precipitation_probability_max"),
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
                temperatureMax: nil,
                temperatureMin: nil,
                weatherCode: current.weatherCode,
                humidity: current.relativeHumidity2m,
                windSpeed: current.windSpeed10m,
                precipitationProbability: nil,
                date: nil
            )
        }

        if let daily = response.daily {
            let forecasts = parseDailyForecasts(daily)
            let key = locationKey(coordinate)
            forecastsByLocation[key] = forecasts
            fetchDatesByLocation[key] = Date()
        }
    }

    private func parseDailyForecasts(_ daily: DailyWeatherResponse) -> [WeatherInfo] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

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
            return WeatherInfo(
                id: dateString,
                temperature: (maxTemp + minTemp) / 2,
                temperatureMax: maxTemp,
                temperatureMin: minTemp,
                weatherCode: code,
                humidity: nil,
                windSpeed: nil,
                precipitationProbability: daily.precipitationProbabilityMax[index],
                date: formatter.date(from: dateString)
            )
        }
    }
}
