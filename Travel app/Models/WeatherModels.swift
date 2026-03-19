import Foundation
import SwiftUI

// MARK: - WeatherAPI.com Response

struct WeatherAPIResponse: Codable {
    let location: WeatherLocation?
    let current: WeatherAPICurrent?
    let forecast: WeatherAPIForecast?
    let alerts: WeatherAPIAlerts?
}

struct WeatherAPIAlerts: Codable {
    let alert: [WeatherAPIAlert]
}

struct WeatherAPIAlert: Codable, Identifiable {
    var id: String { "\(headline ?? "")-\(event ?? "")" }
    let headline: String?
    let severity: String?
    let urgency: String?
    let event: String?
    let desc: String?
    let effective: String?
    let expires: String?

    var isSevere: Bool {
        let s = (severity ?? "").lowercased()
        return s.contains("extreme") || s.contains("severe")
    }

    var severityColor: Color {
        let s = (severity ?? "").lowercased()
        if s.contains("extreme") { return .red }
        if s.contains("severe") { return .orange }
        if s.contains("moderate") { return .yellow }
        return .blue
    }
}

struct WeatherLocation: Codable {
    let name: String?
    let region: String?
    let country: String?
    let lat: Double?
    let lon: Double?
    let tzId: String?
    let localtimeEpoch: Int?
    let localtime: String?

    enum CodingKeys: String, CodingKey {
        case name, region, country, lat, lon, localtime
        case tzId = "tz_id"
        case localtimeEpoch = "localtime_epoch"
    }
}

struct WeatherAPICurrent: Codable {
    let tempC: Double
    let condition: WeatherCondition
    let windKph: Double
    let humidity: Int
    let feelslikeC: Double?
    let uv: Double?
    let precipMm: Double?
    let isDay: Int?
    let pressureMb: Double?
    let visKm: Double?
    let airQuality: WeatherAPIAirQuality?

    enum CodingKeys: String, CodingKey {
        case condition, humidity, uv
        case tempC = "temp_c"
        case windKph = "wind_kph"
        case feelslikeC = "feelslike_c"
        case precipMm = "precip_mm"
        case isDay = "is_day"
        case pressureMb = "pressure_mb"
        case visKm = "vis_km"
        case airQuality = "air_quality"
    }
}

struct WeatherAPIAirQuality: Codable {
    let co: Double?
    let no2: Double?
    let o3: Double?
    let so2: Double?
    let pm2_5: Double?
    let pm10: Double?
    let usEpaIndex: Int?
    let gbDefraIndex: Int?

    enum CodingKeys: String, CodingKey {
        case co, no2, o3, so2, pm2_5, pm10
        case usEpaIndex = "us-epa-index"
        case gbDefraIndex = "gb-defra-index"
    }
}

struct AirQualityInfo {
    let epaIndex: Int
    let pm25: Double
    let pm10: Double

    var levelLocalized: String {
        switch epaIndex {
        case 1: return "Хорошо"
        case 2: return "Умеренно"
        case 3: return "Нездорово для чувствительных"
        case 4: return "Нездорово"
        case 5: return "Очень нездорово"
        case 6: return "Опасно"
        default: return "Неизвестно"
        }
    }

    var color: Color {
        switch epaIndex {
        case 1: return .green
        case 2: return .yellow
        case 3: return .orange
        case 4: return .red
        case 5: return .purple
        case 6: return Color(red: 0.5, green: 0, blue: 0)
        default: return .gray
        }
    }

    var sfSymbol: String {
        switch epaIndex {
        case 1, 2: return "aqi.low"
        case 3, 4: return "aqi.medium"
        default: return "aqi.high"
        }
    }

    var healthAdvice: String {
        switch epaIndex {
        case 1: return "Воздух чистый, идеально для прогулок"
        case 2: return "Приемлемое качество воздуха"
        case 3: return "Чувствительным людям лучше ограничить время на улице"
        case 4: return "Рекомендуется сократить прогулки"
        case 5: return "Избегайте длительного пребывания на улице"
        case 6: return "Оставайтесь в помещении"
        default: return ""
        }
    }
}

struct WeatherCondition: Codable {
    let text: String
    let code: Int
}

struct WeatherAPIForecast: Codable {
    let forecastday: [WeatherAPIForecastDay]
}

struct WeatherAPIForecastDay: Codable {
    let date: String
    let dateEpoch: Int?
    let day: WeatherAPIDay
    let astro: WeatherAPIAstro
    let hour: [WeatherAPIHour]

    enum CodingKeys: String, CodingKey {
        case date, day, astro, hour
        case dateEpoch = "date_epoch"
    }
}

struct WeatherAPIDay: Codable {
    let maxtempC: Double
    let mintempC: Double
    let condition: WeatherCondition
    let dailyChanceOfRain: StringOrInt?
    let dailyChanceOfSnow: StringOrInt?
    let uv: Double?
    let avghumidity: Double?
    let maxwindKph: Double?
    let totalprecipMm: Double?

    enum CodingKeys: String, CodingKey {
        case condition, uv, avghumidity
        case maxtempC = "maxtemp_c"
        case mintempC = "mintemp_c"
        case dailyChanceOfRain = "daily_chance_of_rain"
        case dailyChanceOfSnow = "daily_chance_of_snow"
        case maxwindKph = "maxwind_kph"
        case totalprecipMm = "totalprecip_mm"
    }
}

/// WeatherAPI returns chance_of_rain as string "0" or int 0 depending on endpoint
enum StringOrInt: Codable {
    case string(String)
    case int(Int)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            self = .int(intVal)
        } else if let strVal = try? container.decode(String.self) {
            self = .string(strVal)
        } else {
            self = .int(0)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .int(let i): try container.encode(i)
        }
    }

    var intValue: Int {
        switch self {
        case .string(let s): return Int(s) ?? 0
        case .int(let i): return i
        }
    }
}

struct WeatherAPIAstro: Codable {
    let sunrise: String?
    let sunset: String?
    let moonrise: String?
    let moonset: String?
    let moonPhase: String?

    enum CodingKeys: String, CodingKey {
        case sunrise, sunset, moonrise, moonset
        case moonPhase = "moon_phase"
    }
}

struct WeatherAPIHour: Codable {
    let time: String
    let tempC: Double
    let condition: WeatherCondition
    let chanceOfRain: StringOrInt?
    let chanceOfSnow: StringOrInt?
    let feelslikeC: Double?
    let uv: Double?
    let humidity: Int?
    let windKph: Double?
    let precipMm: Double?

    enum CodingKeys: String, CodingKey {
        case time, condition, humidity, uv
        case tempC = "temp_c"
        case chanceOfRain = "chance_of_rain"
        case chanceOfSnow = "chance_of_snow"
        case feelslikeC = "feelslike_c"
        case windKph = "wind_kph"
        case precipMm = "precip_mm"
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
    let pressureMb: Double?
    let visibilityKm: Double?

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
        sunset: Date? = nil,
        pressureMb: Double? = nil,
        visibilityKm: Double? = nil
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
        self.pressureMb = pressureMb
        self.visibilityKm = visibilityKm
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
    case windyWeather
    case foggyWeather
    case enjoyWeather

    var labelLocalized: String {
        switch self {
        case .takeUmbrella: return String(localized: "Возьмите зонт")
        case .applySunscreen: return String(localized: "Нанесите крем от солнца")
        case .dressWarm: return String(localized: "Оденьтесь теплее")
        case .drinkWater: return String(localized: "Пейте больше воды")
        case .stormWarning: return String(localized: "Ожидается гроза")
        case .windyWeather: return String(localized: "Сильный ветер")
        case .foggyWeather: return String(localized: "Ожидается туман")
        case .enjoyWeather: return String(localized: "Отличная погода для прогулки")
        }
    }

    var capsuleColor: Color {
        switch self {
        case .takeUmbrella: return AppTheme.sakuraPink
        case .applySunscreen: return .orange
        case .dressWarm: return AppTheme.sakuraPink
        case .drinkWater: return .green
        case .stormWarning: return .red
        case .windyWeather: return AppTheme.sakuraPink
        case .foggyWeather: return .gray
        case .enjoyWeather: return .green
        }
    }

    var icon: String {
        switch self {
        case .takeUmbrella: return "umbrella.fill"
        case .applySunscreen: return "sun.max.trianglebadge.exclamationmark"
        case .dressWarm: return "thermometer.snowflake"
        case .drinkWater: return "drop.fill"
        case .stormWarning: return "cloud.bolt.fill"
        case .windyWeather: return "wind"
        case .foggyWeather: return "cloud.fog.fill"
        case .enjoyWeather: return "sun.max.fill"
        }
    }

    // WeatherAPI.com condition codes
    private static let rainCodes: Set<Int> = [
        1063, 1150, 1153, 1168, 1171, 1180, 1183, 1186, 1189,
        1192, 1195, 1198, 1201, 1240, 1243, 1246
    ]
    private static let snowSleetCodes: Set<Int> = [
        1066, 1069, 1072, 1114, 1117, 1204, 1207, 1210, 1213,
        1216, 1219, 1222, 1225, 1237, 1249, 1252, 1255, 1258,
        1261, 1264
    ]
    private static let thunderCodes: Set<Int> = [1087, 1273, 1276, 1279, 1282]
    private static let fogCodes: Set<Int> = [1030, 1135, 1147]
    private static let clearCodes: Set<Int> = [1000, 1003]

    static func recommendations(precip: Int?, uv: Double?, temp: Double?, code: Int?, windSpeed: Double? = nil) -> [WeatherRecommendation] {
        var result: [WeatherRecommendation] = []

        // Rain/snow
        if let p = precip, p >= 30 { result.append(.takeUmbrella) }
        if let c = code, rainCodes.contains(c) || snowSleetCodes.contains(c) {
            if !result.contains(.takeUmbrella) { result.append(.takeUmbrella) }
        }

        // UV
        if let u = uv, u >= 3 { result.append(.applySunscreen) }

        // Cold
        if let t = temp, t < 10 { result.append(.dressWarm) }

        // Heat
        if let t = temp, t > 27 { result.append(.drinkWater) }

        // Thunderstorm
        if let c = code, thunderCodes.contains(c) { result.append(.stormWarning) }

        // Windy
        if let w = windSpeed, w > 10 { result.append(.windyWeather) }

        // Fog
        if let c = code, fogCodes.contains(c) { result.append(.foggyWeather) }

        // Nice weather
        if result.isEmpty, let c = code, clearCodes.contains(c),
           let t = temp, t >= 15 && t <= 27 {
            result.append(.enjoyWeather)
        }

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

// MARK: - WeatherAPI.com Condition Code Mapper

enum WeatherCodeMapper {
    static func sfSymbol(for code: Int) -> String {
        switch code {
        case 1000:       return "sun.max.fill"
        case 1003:       return "cloud.sun.fill"
        case 1006:       return "cloud.fill"
        case 1009:       return "cloud.fill"
        case 1030:       return "cloud.fog.fill"
        case 1063:       return "cloud.drizzle.fill"
        case 1066:       return "cloud.snow.fill"
        case 1069:       return "cloud.sleet.fill"
        case 1072:       return "cloud.sleet.fill"
        case 1087:       return "cloud.bolt.fill"
        case 1114:       return "wind.snow"
        case 1117:       return "cloud.snow.fill"
        case 1135, 1147: return "cloud.fog.fill"
        case 1150, 1153: return "cloud.drizzle.fill"
        case 1168, 1171: return "cloud.sleet.fill"
        case 1180, 1183: return "cloud.rain.fill"
        case 1186, 1189: return "cloud.rain.fill"
        case 1192, 1195: return "cloud.heavyrain.fill"
        case 1198, 1201: return "cloud.sleet.fill"
        case 1204, 1207: return "cloud.sleet.fill"
        case 1210, 1213: return "cloud.snow.fill"
        case 1216, 1219: return "cloud.snow.fill"
        case 1222, 1225: return "cloud.snow.fill"
        case 1237:       return "cloud.hail.fill"
        case 1240:       return "cloud.sun.rain.fill"
        case 1243, 1246: return "cloud.heavyrain.fill"
        case 1249, 1252: return "cloud.sleet.fill"
        case 1255, 1258: return "cloud.snow.fill"
        case 1261, 1264: return "cloud.hail.fill"
        case 1273:       return "cloud.bolt.rain.fill"
        case 1276:       return "cloud.bolt.rain.fill"
        case 1279, 1282: return "cloud.bolt.fill"
        default:         return "questionmark.circle"
        }
    }

    static func localizedName(for code: Int) -> String {
        switch code {
        case 1000: return String(localized: "Ясно")
        case 1003: return String(localized: "Переменная облачность")
        case 1006: return String(localized: "Облачно")
        case 1009: return String(localized: "Пасмурно")
        case 1030: return String(localized: "Дымка")
        case 1063: return String(localized: "Местами дождь")
        case 1066: return String(localized: "Местами снег")
        case 1069: return String(localized: "Мокрый снег")
        case 1072: return String(localized: "Изморось")
        case 1087: return String(localized: "Возможна гроза")
        case 1114: return String(localized: "Позёмок")
        case 1117: return String(localized: "Метель")
        case 1135: return String(localized: "Туман")
        case 1147: return String(localized: "Ледяной туман")
        case 1150, 1153: return String(localized: "Морось")
        case 1168, 1171: return String(localized: "Ледяная морось")
        case 1180: return String(localized: "Лёгкий дождь")
        case 1183: return String(localized: "Лёгкий дождь")
        case 1186: return String(localized: "Временами дождь")
        case 1189: return String(localized: "Дождь")
        case 1192: return String(localized: "Временами ливень")
        case 1195: return String(localized: "Сильный дождь")
        case 1198: return String(localized: "Лёгкий ледяной дождь")
        case 1201: return String(localized: "Ледяной дождь")
        case 1204: return String(localized: "Лёгкий мокрый снег")
        case 1207: return String(localized: "Мокрый снег")
        case 1210, 1213: return String(localized: "Лёгкий снег")
        case 1216, 1219: return String(localized: "Снег")
        case 1222, 1225: return String(localized: "Сильный снег")
        case 1237: return String(localized: "Ледяная крупа")
        case 1240: return String(localized: "Лёгкий ливень")
        case 1243: return String(localized: "Ливень")
        case 1246: return String(localized: "Сильный ливень")
        case 1249: return String(localized: "Мокрый снег")
        case 1252: return String(localized: "Сильный мокрый снег")
        case 1255: return String(localized: "Лёгкий снегопад")
        case 1258: return String(localized: "Снегопад")
        case 1261: return String(localized: "Лёгкий град")
        case 1264: return String(localized: "Град")
        case 1273: return String(localized: "Дождь с грозой")
        case 1276: return String(localized: "Сильный дождь с грозой")
        case 1279: return String(localized: "Снег с грозой")
        case 1282: return String(localized: "Сильный снег с грозой")
        default:   return String(localized: "Неизвестно")
        }
    }
}
