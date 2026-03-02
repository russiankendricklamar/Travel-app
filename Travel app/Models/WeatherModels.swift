import Foundation

// MARK: - Open-Meteo API Response

struct OpenMeteoResponse: Codable {
    let current: CurrentWeatherResponse?
    let daily: DailyWeatherResponse?
}

struct CurrentWeatherResponse: Codable {
    let temperature2m: Double
    let relativeHumidity2m: Int
    let weatherCode: Int
    let windSpeed10m: Double

    enum CodingKeys: String, CodingKey {
        case temperature2m = "temperature_2m"
        case relativeHumidity2m = "relative_humidity_2m"
        case weatherCode = "weather_code"
        case windSpeed10m = "wind_speed_10m"
    }
}

struct DailyWeatherResponse: Codable {
    let time: [String]
    let temperature2mMax: [Double?]
    let temperature2mMin: [Double?]
    let weatherCode: [Int?]
    let precipitationProbabilityMax: [Int?]

    enum CodingKeys: String, CodingKey {
        case time
        case temperature2mMax = "temperature_2m_max"
        case temperature2mMin = "temperature_2m_min"
        case weatherCode = "weather_code"
        case precipitationProbabilityMax = "precipitation_probability_max"
    }
}

// MARK: - Display Model

struct WeatherInfo: Identifiable {
    let id: String
    let temperature: Double
    let temperatureMax: Double?
    let temperatureMin: Double?
    let weatherCode: Int
    let humidity: Int?
    let windSpeed: Double?
    let precipitationProbability: Int?
    let date: Date?

    var conditionRussian: String {
        WeatherCodeMapper.russianName(for: weatherCode)
    }

    var sfSymbol: String {
        WeatherCodeMapper.sfSymbol(for: weatherCode)
    }
}

// MARK: - WMO Weather Code Mapper

enum WeatherCodeMapper {
    static func sfSymbol(for code: Int) -> String {
        switch code {
        case 0:            return "sun.max.fill"
        case 1:            return "sun.min.fill"
        case 2:            return "cloud.sun.fill"
        case 3:            return "cloud.fill"
        case 45, 48:       return "cloud.fog.fill"
        case 51, 53, 55:   return "cloud.drizzle.fill"
        case 56, 57:       return "cloud.sleet.fill"
        case 61, 63, 65:   return "cloud.rain.fill"
        case 66, 67:       return "cloud.sleet.fill"
        case 71, 73, 75:   return "cloud.snow.fill"
        case 77:           return "cloud.snow.fill"
        case 80, 81, 82:   return "cloud.heavyrain.fill"
        case 85, 86:       return "cloud.snow.fill"
        case 95:           return "cloud.bolt.fill"
        case 96, 99:       return "cloud.bolt.rain.fill"
        default:           return "questionmark.circle"
        }
    }

    static func russianName(for code: Int) -> String {
        switch code {
        case 0:            return "Ясно"
        case 1:            return "Малооблачно"
        case 2:            return "Переменная облачность"
        case 3:            return "Пасмурно"
        case 45, 48:       return "Туман"
        case 51, 53, 55:   return "Морось"
        case 56, 57:       return "Ледяная морось"
        case 61, 63, 65:   return "Дождь"
        case 66, 67:       return "Ледяной дождь"
        case 71, 73, 75:   return "Снег"
        case 77:           return "Снежная крупа"
        case 80, 81, 82:   return "Ливень"
        case 85, 86:       return "Снегопад"
        case 95:           return "Гроза"
        case 96, 99:       return "Гроза с градом"
        default:           return "Неизвестно"
        }
    }
}
