import Foundation
import SwiftUI

// MARK: - Open-Meteo API Response

struct OpenMeteoResponse: Codable {
    let current: CurrentWeatherResponse?
    let daily: DailyWeatherResponse?
    let hourly: HourlyWeatherResponse?
}

struct CurrentWeatherResponse: Codable {
    let temperature2m: Double
    let relativeHumidity2m: Int
    let weatherCode: Int
    let windSpeed10m: Double
    let apparentTemperature: Double?

    enum CodingKeys: String, CodingKey {
        case temperature2m = "temperature_2m"
        case relativeHumidity2m = "relative_humidity_2m"
        case weatherCode = "weather_code"
        case windSpeed10m = "wind_speed_10m"
        case apparentTemperature = "apparent_temperature"
    }
}

struct DailyWeatherResponse: Codable {
    let time: [String]
    let temperature2mMax: [Double?]
    let temperature2mMin: [Double?]
    let weatherCode: [Int?]
    let precipitationProbabilityMax: [Int?]
    let sunrise: [String?]?
    let sunset: [String?]?
    let uvIndexMax: [Double?]?

    enum CodingKeys: String, CodingKey {
        case time
        case temperature2mMax = "temperature_2m_max"
        case temperature2mMin = "temperature_2m_min"
        case weatherCode = "weather_code"
        case precipitationProbabilityMax = "precipitation_probability_max"
        case sunrise
        case sunset
        case uvIndexMax = "uv_index_max"
    }
}

struct HourlyWeatherResponse: Codable {
    let time: [String]
    let temperature2m: [Double?]
    let weatherCode: [Int?]
    let precipitationProbability: [Int?]
    let apparentTemperature: [Double?]
    let uvIndex: [Double?]

    enum CodingKeys: String, CodingKey {
        case time
        case temperature2m = "temperature_2m"
        case weatherCode = "weather_code"
        case precipitationProbability = "precipitation_probability"
        case apparentTemperature = "apparent_temperature"
        case uvIndex = "uv_index"
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
    let apparentTemperature: Double?
    let uvIndexMax: Double?
    let sunrise: Date?
    let sunset: Date?

    init(
        id: String,
        temperature: Double,
        temperatureMax: Double? = nil,
        temperatureMin: Double? = nil,
        weatherCode: Int,
        humidity: Int? = nil,
        windSpeed: Double? = nil,
        precipitationProbability: Int? = nil,
        date: Date? = nil,
        apparentTemperature: Double? = nil,
        uvIndexMax: Double? = nil,
        sunrise: Date? = nil,
        sunset: Date? = nil
    ) {
        self.id = id
        self.temperature = temperature
        self.temperatureMax = temperatureMax
        self.temperatureMin = temperatureMin
        self.weatherCode = weatherCode
        self.humidity = humidity
        self.windSpeed = windSpeed
        self.precipitationProbability = precipitationProbability
        self.date = date
        self.apparentTemperature = apparentTemperature
        self.uvIndexMax = uvIndexMax
        self.sunrise = sunrise
        self.sunset = sunset
    }

    var conditionLocalized: String {
        WeatherCodeMapper.localizedName(for: weatherCode)
    }

    var sfSymbol: String {
        WeatherCodeMapper.sfSymbol(for: weatherCode)
    }
}

// MARK: - Hourly Weather Info

struct HourlyWeatherInfo: Identifiable {
    let id: String
    let hour: Date
    let temperature: Double
    let weatherCode: Int
    let precipitationProbability: Int?
    let apparentTemperature: Double?
    let uvIndex: Double?

    var sfSymbol: String {
        WeatherCodeMapper.sfSymbol(for: weatherCode)
    }

    var hourLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: hour)
    }
}

// MARK: - Weather Recommendation

enum WeatherRecommendation: CaseIterable {
    case takeUmbrella
    case applySunscreen
    case dressWarm
    case drinkWater
    case stormWarning

    var labelLocalized: String {
        switch self {
        case .takeUmbrella: return String(localized: "Возьмите зонт")
        case .applySunscreen: return String(localized: "Нанесите крем от солнца")
        case .dressWarm: return String(localized: "Оденьтесь теплее")
        case .drinkWater: return String(localized: "Пейте больше воды")
        case .stormWarning: return String(localized: "Ожидается гроза")
        }
    }

    var capsuleColor: Color {
        switch self {
        case .takeUmbrella: return .blue
        case .applySunscreen: return .orange
        case .dressWarm: return .cyan
        case .drinkWater: return .green
        case .stormWarning: return .red
        }
    }

    var icon: String {
        switch self {
        case .takeUmbrella: return "umbrella.fill"
        case .applySunscreen: return "sun.max.trianglebadge.exclamationmark"
        case .dressWarm: return "thermometer.snowflake"
        case .drinkWater: return "drop.fill"
        case .stormWarning: return "cloud.bolt.fill"
        }
    }

    static func recommendations(precip: Int?, uv: Double?, temp: Double?, code: Int?) -> [WeatherRecommendation] {
        var result: [WeatherRecommendation] = []
        if let p = precip, p >= 50 { result.append(.takeUmbrella) }
        if let u = uv, u > 5 { result.append(.applySunscreen) }
        if let t = temp, t < 5 { result.append(.dressWarm) }
        if let t = temp, t > 30 { result.append(.drinkWater) }
        if let c = code, [95, 96, 99].contains(c) { result.append(.stormWarning) }
        return result
    }
}

// MARK: - UV Index Level

enum UVIndexLevel {
    case low
    case moderate
    case high
    case veryHigh

    init(uvIndex: Double) {
        switch uvIndex {
        case ..<3: self = .low
        case 3..<6: self = .moderate
        case 6..<8: self = .high
        default: self = .veryHigh
        }
    }

    var color: Color {
        switch self {
        case .low: return .green
        case .moderate: return .yellow
        case .high: return .orange
        case .veryHigh: return .red
        }
    }

    var labelLocalized: String {
        switch self {
        case .low: return String(localized: "Низкий")
        case .moderate: return String(localized: "Средний")
        case .high: return String(localized: "Высокий")
        case .veryHigh: return String(localized: "Очень высокий")
        }
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

    static func localizedName(for code: Int) -> String {
        switch code {
        case 0:            return String(localized: "Ясно")
        case 1:            return String(localized: "Малооблачно")
        case 2:            return String(localized: "Переменная облачность")
        case 3:            return String(localized: "Пасмурно")
        case 45, 48:       return String(localized: "Туман")
        case 51, 53, 55:   return String(localized: "Морось")
        case 56, 57:       return String(localized: "Ледяная морось")
        case 61, 63, 65:   return String(localized: "Дождь")
        case 66, 67:       return String(localized: "Ледяной дождь")
        case 71, 73, 75:   return String(localized: "Снег")
        case 77:           return String(localized: "Снежная крупа")
        case 80, 81, 82:   return String(localized: "Ливень")
        case 85, 86:       return String(localized: "Снегопад")
        case 95:           return String(localized: "Гроза")
        case 96, 99:       return String(localized: "Гроза с градом")
        default:           return String(localized: "Неизвестно")
        }
    }
}
