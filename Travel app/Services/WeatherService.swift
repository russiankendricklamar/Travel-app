import Foundation
import CoreLocation

@Observable
final class WeatherService {
    static let shared = WeatherService()

    var currentWeather: WeatherInfo?
    var dailyForecasts: [WeatherInfo] = []
    var isLoading = false
    var errorMessage: String?

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

    // MARK: - Public

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
            parseResponse(decoded)

            lastFetchDate = Date()
            lastFetchCoordinate = coordinate
        } catch {
            errorMessage = "Не удалось загрузить погоду"
        }

        isLoading = false
    }

    func forecast(for date: Date) -> WeatherInfo? {
        let calendar = Calendar.current
        return dailyForecasts.first { info in
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

    private func parseResponse(_ response: OpenMeteoResponse) {
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
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"

            dailyForecasts = daily.time.enumerated().compactMap { index, dateString in
                guard index < daily.temperature2mMax.count,
                      index < daily.temperature2mMin.count,
                      index < daily.weatherCode.count,
                      index < daily.precipitationProbabilityMax.count else {
                    return nil
                }
                return WeatherInfo(
                    id: dateString,
                    temperature: (daily.temperature2mMax[index] + daily.temperature2mMin[index]) / 2,
                    temperatureMax: daily.temperature2mMax[index],
                    temperatureMin: daily.temperature2mMin[index],
                    weatherCode: daily.weatherCode[index],
                    humidity: nil,
                    windSpeed: nil,
                    precipitationProbability: daily.precipitationProbabilityMax[index],
                    date: formatter.date(from: dateString)
                )
            }
        }
    }
}
