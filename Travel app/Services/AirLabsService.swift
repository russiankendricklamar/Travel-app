import Foundation
import CoreLocation

@Observable
final class AirLabsService {
    static let shared = AirLabsService()

    var isLoading = false
    var lastError: String?
    var cachedFlights: [String: FlightData] = [:]
    private var lastFetchDates: [String: Date] = [:]
    private let cacheInterval: TimeInterval = 300

    private var liveCacheDates: [String: Date] = [:]
    private var liveCache: [String: LivePosition] = [:]
    private let liveCacheInterval: TimeInterval = 60

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)
    }

    var hasApiKey: Bool {
        !Secrets.airLabsApiKey.isEmpty
    }

    func fetchFlight(number: String, date: Date? = nil) async -> FlightData? {
        let stripped = number
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .uppercased()
        // Remove leading zeros from flight number: "MU0272" → "MU272"
        let letters = stripped.prefix(while: \.isLetter)
        let digits = stripped.drop(while: \.isLetter)
        let trimmedDigits = digits.drop(while: { $0 == "0" })
        let cleaned = String(letters) + String(trimmedDigits.isEmpty ? digits.suffix(1) : trimmedDigits)

        if let cached = cachedFlights[cleaned],
           let lastDate = lastFetchDates[cleaned],
           Date().timeIntervalSince(lastDate) < cacheInterval {
            return cached
        }

        guard hasApiKey else {
            lastError = "API-ключ AirLabs не настроен"
            return nil
        }

        isLoading = true
        lastError = nil
        defer { isLoading = false }

        let key = Secrets.airLabsApiKey

        // Only use live schedules for today's flights (±1 day)
        let useSchedules: Bool
        if let date {
            let daysDiff = abs(Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0)
            useSchedules = daysDiff <= 1
        } else {
            useSchedules = true
        }

        // 1) Try live schedules first (today's flights with real-time data)
        if useSchedules, let flight = await fetchFromSchedules(key: key, flightIata: cleaned, date: date) {
            cachedFlights[cleaned] = flight
            lastFetchDates[cleaned] = Date()
            return flight
        }

        // 2) Fallback to routes (static timetable — works for any flight)
        if let flight = await fetchFromRoutes(key: key, flightIata: cleaned, date: date) {
            cachedFlights[cleaned] = flight
            lastFetchDates[cleaned] = Date()
            return flight
        }

        if lastError == nil {
            lastError = "Рейс \(cleaned) не найден"
        }
        return nil
    }

    // MARK: - Live Position (for active flights only)

    func fetchLivePosition(flightIata: String) async -> LivePosition? {
        let cleaned = flightIata
            .replacingOccurrences(of: " ", with: "")
            .uppercased()

        if let cached = liveCache[cleaned],
           let lastDate = liveCacheDates[cleaned],
           Date().timeIntervalSince(lastDate) < liveCacheInterval {
            return cached
        }

        guard hasApiKey else { return nil }
        let key = Secrets.airLabsApiKey

        guard let url = URL(string: "https://airlabs.co/api/v9/flights?api_key=\(key)&flight_iata=\(cleaned)") else { return nil }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }

            let decoded = try JSONDecoder().decode(AirLabsLiveResponse.self, from: data)
            guard let entries = decoded.response, let entry = entries.first else { return nil }

            let position = LivePosition(
                latitude: entry.lat,
                longitude: entry.lng,
                altitude: entry.alt,
                speed: entry.speed,
                direction: entry.dir
            )
            liveCache[cleaned] = position
            liveCacheDates[cleaned] = Date()
            return position
        } catch {
            return nil
        }
    }

    // MARK: - Schedules (live data)

    private func fetchFromSchedules(key: String, flightIata: String, date: Date?) async -> FlightData? {
        guard let url = URL(string: "https://airlabs.co/api/v9/schedules?api_key=\(key)&flight_iata=\(flightIata)") else { return nil }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }

            let decoded = try JSONDecoder().decode(AirLabsSchedulesResponse.self, from: data)
            guard let entries = decoded.response, !entries.isEmpty else { return nil }

            let entry: AirLabsScheduleEntry
            if let date, entries.count > 1 {
                let target = date.timeIntervalSince1970
                entry = entries.min(by: {
                    abs(Double($0.dep_time_ts ?? 0) - target) < abs(Double($1.dep_time_ts ?? 0) - target)
                }) ?? entries[0]
            } else {
                entry = entries[0]
            }
            return FlightData(fromSchedule: entry)
        } catch {
            return nil
        }
    }

    // MARK: - Routes (static timetable)

    private func fetchFromRoutes(key: String, flightIata: String, date: Date?) async -> FlightData? {
        guard let url = URL(string: "https://airlabs.co/api/v9/routes?api_key=\(key)&flight_iata=\(flightIata)") else { return nil }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }

            let decoded = try JSONDecoder().decode(AirLabsRoutesResponse.self, from: data)
            guard let entries = decoded.response, let entry = entries.first else { return nil }
            return FlightData(fromRoute: entry, tripDate: date)
        } catch {
            return nil
        }
    }
}

// MARK: - Live Position Model

struct LivePosition {
    let latitude: Double?
    let longitude: Double?
    let altitude: Double?   // meters
    let speed: Double?      // km/h
    let direction: Double?  // degrees

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var altitudeFeet: Int? {
        guard let alt = altitude else { return nil }
        return Int(alt * 3.28084)
    }

    var speedKmh: Int? {
        guard let spd = speed else { return nil }
        return Int(spd)
    }
}

// MARK: - FlightData (shared model)

struct FlightData {
    let flightIata: String
    let airlineName: String
    let status: String

    let departureAirport: String
    let departureIata: String
    let departureTime: Date?
    let departureEstimated: Date?
    let departureGate: String?
    let departureTerminal: String?
    let departureDelay: Int?

    let arrivalAirport: String
    let arrivalIata: String
    let arrivalTime: Date?
    let arrivalEstimated: Date?
    let arrivalGate: String?
    let arrivalTerminal: String?
    let arrivalDelay: Int?

    // New fields
    let aircraftType: String?
    let arrivalBaggage: String?
    let codeshareFlightIata: String?
    let codeshareAirlineIata: String?

    var isDelayed: Bool {
        (departureDelay ?? 0) > 0 || (arrivalDelay ?? 0) > 0
    }

    var durationSeconds: TimeInterval? {
        guard let dep = departureEstimated ?? departureTime,
              let arr = arrivalEstimated ?? arrivalTime else { return nil }
        let diff = arr.timeIntervalSince(dep)
        return diff > 0 ? diff : nil
    }

    var durationFormatted: String? {
        guard let seconds = durationSeconds else { return nil }
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return minutes > 0 ? "\(hours) ч \(minutes) мин" : "\(hours) ч"
        }
        return "\(minutes) мин"
    }

    var statusLocalized: String {
        switch status {
        case "scheduled": return String(localized: "По расписанию")
        case "active": return String(localized: "В воздухе")
        case "landed": return String(localized: "Прилетел")
        case "cancelled": return String(localized: "Отменён")
        case "diverted": return String(localized: "Перенаправлен")
        default: return status.capitalized
        }
    }

    var departureCityName: String {
        Self.airportCities[departureIata] ?? departureAirport
    }

    var arrivalCityName: String {
        Self.airportCities[arrivalIata] ?? arrivalAirport
    }

    // MARK: - Computed display names from dictionaries

    var airlineDisplayName: String {
        let code = String(flightIata.prefix(while: \.isLetter))
        return Self.airlineNames[code] ?? airlineName
    }

    var aircraftTypeName: String? {
        guard let type = aircraftType else { return nil }
        return Self.aircraftTypeNames[type]
    }

    var departureAirportFullName: String? {
        Self.airportFullNames[departureIata]
    }

    var arrivalAirportFullName: String? {
        Self.airportFullNames[arrivalIata]
    }

    // MARK: - IATA → City

    static let airportCities: [String: String] = [
        // Россия
        "SVO": "Москва", "DME": "Москва", "VKO": "Москва", "ZIA": "Москва",
        "LED": "Санкт-Петербург", "AER": "Сочи", "KZN": "Казань",
        "SVX": "Екатеринбург", "OVB": "Новосибирск", "KUF": "Самара",
        "ROV": "Ростов-на-Дону", "KRR": "Краснодар", "UFA": "Уфа",
        "VOG": "Волгоград", "KGD": "Калининград", "MRV": "Минеральные Воды",
        "VVO": "Владивосток", "KHV": "Хабаровск", "IKT": "Иркутск",
        "GOJ": "Нижний Новгород", "CEK": "Челябинск", "PEE": "Пермь",
        "TJM": "Тюмень", "OMS": "Омск", "MCX": "Махачкала",
        // Япония
        "NRT": "Токио", "HND": "Токио", "KIX": "Осака",
        "ITM": "Осака", "CTS": "Саппоро", "FUK": "Фукуока",
        "NGO": "Нагоя", "OKA": "Окинава",
        // Китай
        "PEK": "Пекин", "PKX": "Пекин", "PVG": "Шанхай", "SHA": "Шанхай",
        "CAN": "Гуанчжоу", "SZX": "Шэньчжэнь", "CTU": "Чэнду",
        "HGH": "Ханчжоу", "XIY": "Сиань", "CKG": "Чунцин",
        // Юго-Восточная Азия
        "BKK": "Бангкок", "DMK": "Бангкок", "HKT": "Пхукет",
        "SIN": "Сингапур", "KUL": "Куала-Лумпур", "CGK": "Джакарта",
        "SGN": "Хошимин", "HAN": "Ханой", "DPS": "Бали",
        "MNL": "Манила", "RGN": "Янгон", "PNH": "Пномпень",
        // Корея
        "ICN": "Сеул", "GMP": "Сеул", "PUS": "Пусан", "CJU": "Чеджу",
        // Индия
        "DEL": "Дели", "BOM": "Мумбаи", "BLR": "Бангалор",
        "MAA": "Ченнай", "CCU": "Калькутта", "GOI": "Гоа",
        // Ближний Восток
        "DXB": "Дубай", "AUH": "Абу-Даби", "DOH": "Доха",
        "RUH": "Эр-Рияд", "JED": "Джидда", "BAH": "Бахрейн",
        "MCT": "Маскат", "AMM": "Амман", "BEY": "Бейрут",
        "TLV": "Тель-Авив",
        // Турция
        "IST": "Стамбул", "SAW": "Стамбул", "AYT": "Анталья",
        "ADA": "Адана", "ESB": "Анкара", "ADB": "Измир",
        "DLM": "Даламан", "BJV": "Бодрум",
        // Европа
        "CDG": "Париж", "ORY": "Париж",
        "LHR": "Лондон", "LGW": "Лондон", "STN": "Лондон",
        "FCO": "Рим", "MXP": "Милан", "VCE": "Венеция",
        "BCN": "Барселона", "MAD": "Мадрид", "AGP": "Малага",
        "FRA": "Франкфурт", "MUC": "Мюнхен", "TXL": "Берлин", "BER": "Берлин",
        "AMS": "Амстердам", "BRU": "Брюссель", "ZRH": "Цюрих",
        "VIE": "Вена", "PRG": "Прага", "WAW": "Варшава",
        "BUD": "Будапешт", "ATH": "Афины", "LIS": "Лиссабон",
        "HEL": "Хельсинки", "ARN": "Стокгольм", "CPH": "Копенгаген",
        "OSL": "Осло", "DUB": "Дублин",
        // СНГ
        "TAS": "Ташкент", "ALA": "Алматы", "NQZ": "Астана", "TSE": "Астана",
        "GYD": "Баку", "TBS": "Тбилиси", "EVN": "Ереван",
        "MSQ": "Минск", "KBP": "Киев", "IEV": "Киев",
        "FRU": "Бишкек", "DYU": "Душанбе",
        // Америка
        "JFK": "Нью-Йорк", "EWR": "Нью-Йорк", "LGA": "Нью-Йорк",
        "LAX": "Лос-Анджелес", "SFO": "Сан-Франциско", "ORD": "Чикаго",
        "MIA": "Майами", "ATL": "Атланта", "DFW": "Даллас",
        "IAD": "Вашингтон", "DCA": "Вашингтон", "BOS": "Бостон",
        "SEA": "Сиэтл", "LAS": "Лас-Вегас", "DEN": "Денвер",
        "YYZ": "Торонто", "YVR": "Ванкувер",
        "MEX": "Мехико", "CUN": "Канкун",
        "GRU": "Сан-Паулу", "GIG": "Рио-де-Жанейро",
        "EZE": "Буэнос-Айрес", "SCL": "Сантьяго", "BOG": "Богота",
        "LIM": "Лима", "HAV": "Гавана",
        // Африка
        "CAI": "Каир", "HRG": "Хургада", "SSH": "Шарм-эль-Шейх",
        "CMN": "Касабланка", "JNB": "Йоханнесбург", "CPT": "Кейптаун",
        "NBO": "Найроби", "ADD": "Аддис-Абеба", "DSS": "Дакар",
        // Океания
        "SYD": "Сидней", "MEL": "Мельбурн", "AKL": "Окленд",
        // Гонконг, Макао, Тайвань
        "HKG": "Гонконг", "MFM": "Макао", "TPE": "Тайбэй",
    ]
}

// MARK: - Airline Names Dictionary

extension FlightData {
    static let airlineNames: [String: String] = [
        // Россия
        "SU": "Аэрофлот", "S7": "S7 Airlines", "DP": "Победа", "UT": "ЮТэйр",
        "U6": "Уральские авиалинии", "N4": "Nordwind", "5N": "Smartavia",
        "FV": "Россия", "6R": "Аврора", "Y7": "NordStar", "WZ": "Red Wings",
        "IO": "ИрАэро", "GH": "Глобус", "EO": "Азур Эйр",
        // Турция
        "TK": "Turkish Airlines", "PC": "Pegasus Airlines", "XQ": "SunExpress",
        "VF": "AJet",
        // Ближний Восток
        "EK": "Emirates", "QR": "Qatar Airways", "EY": "Etihad Airways",
        "SV": "Saudia", "GF": "Gulf Air", "WY": "Oman Air",
        "RJ": "Royal Jordanian", "ME": "Middle East Airlines",
        "LY": "El Al", "FZ": "Flydubai", "G9": "Air Arabia",
        // Азия
        "CZ": "China Southern", "CA": "Air China", "MU": "China Eastern",
        "HU": "Hainan Airlines", "3U": "Sichuan Airlines",
        "SQ": "Singapore Airlines", "CX": "Cathay Pacific",
        "TG": "Thai Airways", "GA": "Garuda Indonesia",
        "MH": "Malaysia Airlines", "VN": "Vietnam Airlines",
        "PR": "Philippine Airlines", "KE": "Korean Air",
        "OZ": "Asiana Airlines", "NH": "ANA", "JL": "Japan Airlines",
        "AI": "Air India", "6E": "IndiGo", "AK": "AirAsia",
        "TR": "Scoot", "VJ": "VietJet Air",
        // Европа
        "LH": "Lufthansa", "BA": "British Airways",
        "AF": "Air France", "KL": "KLM",
        "AZ": "ITA Airways", "IB": "Iberia", "VY": "Vueling",
        "FR": "Ryanair", "U2": "easyJet", "W6": "Wizz Air",
        "SK": "SAS", "AY": "Finnair", "OS": "Austrian Airlines",
        "LX": "Swiss", "TP": "TAP Portugal", "LO": "LOT Polish",
        "OK": "Czech Airlines", "RO": "TAROM",
        "A3": "Aegean Airlines", "SN": "Brussels Airlines",
        "EI": "Aer Lingus", "DY": "Norwegian",
        // СНГ
        "KC": "Air Astana", "HY": "Uzbekistan Airways",
        "J2": "Azerbaijan Airlines", "B2": "Belavia",
        "PS": "UIA", "FG": "Ariana Afghan",
        // Америка
        "AA": "American Airlines", "DL": "Delta Air Lines",
        "UA": "United Airlines", "WN": "Southwest Airlines",
        "B6": "JetBlue", "AS": "Alaska Airlines",
        "AC": "Air Canada", "WS": "WestJet",
        "AM": "Aeromexico", "AV": "Avianca",
        "LA": "LATAM Airlines", "CM": "Copa Airlines",
        "G3": "Gol", "AD": "Azul",
        // Африка
        "MS": "EgyptAir", "ET": "Ethiopian Airlines",
        "SA": "South African Airways", "KQ": "Kenya Airways",
        "AT": "Royal Air Maroc",
        // Океания
        "QF": "Qantas", "NZ": "Air New Zealand", "JQ": "Jetstar",
    ]
}

// MARK: - Airport Full Names Dictionary

extension FlightData {
    static let airportFullNames: [String: String] = [
        // Россия
        "SVO": "Шереметьево", "DME": "Домодедово", "VKO": "Внуково", "ZIA": "Жуковский",
        "LED": "Пулково", "AER": "Сочи (Адлер)", "KZN": "Казань",
        "SVX": "Кольцово", "OVB": "Толмачёво", "KUF": "Курумоч",
        "ROV": "Платов", "KRR": "Пашковский", "UFA": "Уфа",
        "KGD": "Храброво", "MRV": "Минеральные Воды",
        "VVO": "Кневичи", "KHV": "Хабаровск-Новый", "IKT": "Иркутск",
        "GOJ": "Стригино", "CEK": "Баландино",
        // Япония
        "NRT": "Нарита", "HND": "Ханеда", "KIX": "Кансай",
        "ITM": "Итами", "CTS": "Син-Титосэ", "FUK": "Фукуока",
        "NGO": "Тюбу", "OKA": "Наха",
        // Китай
        "PEK": "Шоуду", "PKX": "Дасин", "PVG": "Пудун",
        "SHA": "Хунцяо", "CAN": "Байюнь",
        // Юго-Восточная Азия
        "BKK": "Суварнабхуми", "DMK": "Дон Муанг",
        "SIN": "Чанги", "KUL": "KLIA", "CGK": "Сукарно-Хатта",
        "SGN": "Таншоннят", "HAN": "Нойбай", "DPS": "Нгурах-Рай",
        "HKT": "Пхукет",
        // Корея
        "ICN": "Инчхон", "GMP": "Кимпхо",
        // Индия
        "DEL": "Индира Ганди", "BOM": "Чатрапати Шиваджи",
        // Ближний Восток
        "DXB": "Дубай", "AUH": "Абу-Даби", "DOH": "Хамад",
        "JED": "Король Абдулазиз", "TLV": "Бен-Гурион",
        // Турция
        "IST": "Стамбул", "SAW": "Сабиха Гёкчен",
        "AYT": "Анталья", "ADB": "Измир",
        "DLM": "Даламан", "BJV": "Бодрум-Милас",
        // Европа
        "CDG": "Шарль-де-Голль", "ORY": "Орли",
        "LHR": "Хитроу", "LGW": "Гатвик", "STN": "Станстед",
        "FCO": "Фьюмичино", "MXP": "Мальпенса", "VCE": "Марко Поло",
        "BCN": "Эль-Прат", "MAD": "Барахас",
        "FRA": "Франкфурт", "MUC": "Мюнхен", "BER": "Бранденбург",
        "AMS": "Схипхол", "BRU": "Завентем", "ZRH": "Цюрих",
        "VIE": "Швехат", "PRG": "Вацлав Гавел", "WAW": "Шопен",
        "BUD": "Будапешт Листа Ференца", "ATH": "Элефтериос Венизелос",
        "LIS": "Портела", "HEL": "Вантаа",
        "ARN": "Арланда", "CPH": "Каструп", "OSL": "Гардермуэн",
        "DUB": "Дублин",
        // СНГ
        "TAS": "Ташкент", "ALA": "Алматы", "NQZ": "Назарбаев",
        "GYD": "Гейдар Алиев", "TBS": "Тбилиси", "EVN": "Звартноц",
        "MSQ": "Национальный", "KBP": "Борисполь",
        // Америка
        "JFK": "Кеннеди", "EWR": "Ньюарк", "LGA": "ЛаГуардия",
        "LAX": "Лос-Анджелес", "SFO": "Сан-Франциско", "ORD": "О'Хара",
        "MIA": "Майами", "ATL": "Хартсфилд-Джексон",
        "IAD": "Даллес", "BOS": "Логан",
        "YYZ": "Пирсон", "YVR": "Ванкувер",
        "MEX": "Бенито Хуарес", "CUN": "Канкун",
        "GRU": "Гуарульюс", "GIG": "Галеан",
        "EZE": "Министро Пистарини",
        // Африка
        "CAI": "Каир", "HRG": "Хургада", "SSH": "Шарм-эль-Шейх",
        "JNB": "Тамбо", "CPT": "Кейптаун",
        // Океания
        "SYD": "Кингсфорд-Смит", "MEL": "Тулламарин", "AKL": "Окленд",
        // Гонконг
        "HKG": "Чхеклапкок", "TPE": "Таоюань",
    ]
}

// MARK: - Aircraft Type Names Dictionary

extension FlightData {
    static let aircraftTypeNames: [String: String] = [
        "B738": "Boeing 737-800", "B739": "Boeing 737-900",
        "B737": "Boeing 737-700", "B38M": "Boeing 737 MAX 8",
        "B39M": "Boeing 737 MAX 9", "B3XM": "Boeing 737 MAX 10",
        "B752": "Boeing 757-200", "B753": "Boeing 757-300",
        "B763": "Boeing 767-300", "B772": "Boeing 777-200",
        "B773": "Boeing 777-300", "B77W": "Boeing 777-300ER",
        "B788": "Boeing 787-8", "B789": "Boeing 787-9",
        "B78X": "Boeing 787-10",
        "A319": "Airbus A319", "A320": "Airbus A320",
        "A20N": "Airbus A320neo", "A321": "Airbus A321",
        "A21N": "Airbus A321neo", "A332": "Airbus A330-200",
        "A333": "Airbus A330-300", "A338": "Airbus A330-800neo",
        "A339": "Airbus A330-900neo",
        "A342": "Airbus A340-200", "A343": "Airbus A340-300",
        "A345": "Airbus A340-500", "A346": "Airbus A340-600",
        "A359": "Airbus A350-900", "A35K": "Airbus A350-1000",
        "A388": "Airbus A380-800",
        "E190": "Embraer E190", "E195": "Embraer E195",
        "E290": "Embraer E190-E2", "E295": "Embraer E195-E2",
        "CRJ9": "Bombardier CRJ-900", "SU95": "Sukhoi Superjet 100",
        "B744": "Boeing 747-400", "B748": "Boeing 747-8",
        "AT76": "ATR 72-600",
    ]
}

// MARK: - Schedules Response Models

private struct AirLabsSchedulesResponse: Codable {
    let response: [AirLabsScheduleEntry]?
    let error: AirLabsError?
}

private struct AirLabsError: Codable {
    let message: String?
    let code: String?
}

private struct AirLabsScheduleEntry: Codable {
    let flight_iata: String?
    let airline_iata: String?
    let dep_iata: String?
    let arr_iata: String?
    let dep_terminal: String?
    let dep_gate: String?
    let dep_time_ts: Int?
    let dep_estimated_ts: Int?
    let dep_actual_ts: Int?
    let arr_terminal: String?
    let arr_gate: String?
    let arr_baggage: String?
    let arr_time_ts: Int?
    let arr_estimated_ts: Int?
    let arr_actual_ts: Int?
    let status: String?
    let duration: Int?
    let dep_delayed: Int?
    let arr_delayed: Int?
    let cs_flight_iata: String?
    let cs_airline_iata: String?
}

// MARK: - Routes Response Models

private struct AirLabsRoutesResponse: Codable {
    let response: [AirLabsRouteEntry]?
    let error: AirLabsError?
}

private struct AirLabsRouteEntry: Codable {
    let flight_iata: String?
    let airline_iata: String?
    let dep_iata: String?
    let arr_iata: String?
    let dep_terminals: [String]?
    let arr_terminals: [String]?
    let dep_time: String?      // "10:55"
    let arr_time: String?      // "13:45"
    let duration: Int?         // minutes
    let days: [String]?
    let aircraft_icao: String?
}

// MARK: - Live Flight Response Models

private struct AirLabsLiveResponse: Codable {
    let response: [AirLabsLiveEntry]?
    let error: AirLabsError?
}

private struct AirLabsLiveEntry: Codable {
    let flight_iata: String?
    let lat: Double?
    let lng: Double?
    let alt: Double?
    let speed: Double?
    let dir: Double?
}

// MARK: - FlightData init from Schedule (live)

extension FlightData {
    fileprivate init(fromSchedule entry: AirLabsScheduleEntry) {
        self.flightIata = entry.flight_iata ?? ""

        let airlineCode = entry.airline_iata ?? String((entry.flight_iata ?? "").prefix(while: \.isLetter))
        self.airlineName = Self.airlineNames[airlineCode] ?? ""

        let rawStatus = entry.status ?? "scheduled"
        self.status = rawStatus == "en-route" ? "active" : rawStatus

        let depIata = entry.dep_iata ?? ""
        let arrIata = entry.arr_iata ?? ""

        self.departureAirport = Self.airportFullNames[depIata] ?? ""
        self.departureIata = depIata
        self.departureTime = entry.dep_time_ts
            .map { Date(timeIntervalSince1970: TimeInterval($0)) }
        self.departureEstimated = (entry.dep_actual_ts ?? entry.dep_estimated_ts)
            .map { Date(timeIntervalSince1970: TimeInterval($0)) }
        self.departureGate = entry.dep_gate
        self.departureTerminal = entry.dep_terminal
        self.departureDelay = entry.dep_delayed

        self.arrivalAirport = Self.airportFullNames[arrIata] ?? ""
        self.arrivalIata = arrIata
        self.arrivalTime = entry.arr_time_ts
            .map { Date(timeIntervalSince1970: TimeInterval($0)) }
        self.arrivalEstimated = (entry.arr_actual_ts ?? entry.arr_estimated_ts)
            .map { Date(timeIntervalSince1970: TimeInterval($0)) }
        self.arrivalGate = entry.arr_gate
        self.arrivalTerminal = entry.arr_terminal
        self.arrivalDelay = entry.arr_delayed

        self.aircraftType = nil // schedules don't return aircraft
        self.arrivalBaggage = entry.arr_baggage
        self.codeshareFlightIata = entry.cs_flight_iata
        self.codeshareAirlineIata = entry.cs_airline_iata
    }
}

// MARK: - FlightData init from Route (static timetable)

extension FlightData {
    fileprivate init(fromRoute entry: AirLabsRouteEntry, tripDate: Date?) {
        self.flightIata = entry.flight_iata ?? ""

        let airlineCode = entry.airline_iata ?? String((entry.flight_iata ?? "").prefix(while: \.isLetter))
        self.airlineName = Self.airlineNames[airlineCode] ?? ""

        self.status = "scheduled"

        let depIata = entry.dep_iata ?? ""
        let arrIata = entry.arr_iata ?? ""

        self.departureAirport = Self.airportFullNames[depIata] ?? ""
        self.departureIata = depIata
        self.departureTerminal = entry.dep_terminals?.first
        self.departureGate = nil
        self.departureDelay = nil

        self.arrivalAirport = Self.airportFullNames[arrIata] ?? ""
        self.arrivalIata = arrIata
        self.arrivalTerminal = entry.arr_terminals?.first
        self.arrivalGate = nil
        self.arrivalDelay = nil

        // Build departure/arrival Date from "HH:mm" + trip date
        let baseDate = tripDate ?? Date()
        let dep = Self.buildDate(timeString: entry.dep_time, on: baseDate)
        var arr = Self.buildDate(timeString: entry.arr_time, on: baseDate)

        // If arrival appears before departure, the flight crosses midnight → +1 day
        if let d = dep, let a = arr, a <= d {
            arr = Calendar.current.date(byAdding: .day, value: 1, to: a)
        }

        self.departureTime = dep
        self.arrivalTime = arr
        self.departureEstimated = nil
        self.arrivalEstimated = nil

        self.aircraftType = entry.aircraft_icao
        self.arrivalBaggage = nil
        self.codeshareFlightIata = nil
        self.codeshareAirlineIata = nil
    }

    private static func buildDate(timeString: String?, on date: Date) -> Date? {
        guard let timeString, timeString.contains(":") else { return nil }
        let parts = timeString.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else { return nil }
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        comps.hour = hour
        comps.minute = minute
        return Calendar.current.date(from: comps)
    }
}

// MARK: - Airport Coordinates (IATA → CLLocationCoordinate2D)

extension FlightData {
    static func coordinate(forIata iata: String) -> CLLocationCoordinate2D? {
        guard let c = airportCoordinates[iata] else { return nil }
        return CLLocationCoordinate2D(latitude: c.0, longitude: c.1)
    }

    static let airportCoordinates: [String: (Double, Double)] = [
        // Russia
        "SVO": (55.97, 37.41), "DME": (55.41, 37.91), "VKO": (55.60, 37.26), "ZIA": (55.55, 38.15),
        "LED": (59.80, 30.26), "AER": (43.45, 39.96), "KZN": (55.61, 49.28),
        "SVX": (56.74, 60.80), "OVB": (55.01, 82.65), "KUF": (53.50, 50.16),
        "ROV": (47.49, 39.92), "KRR": (45.03, 39.17), "UFA": (54.56, 55.87),
        "VOG": (48.78, 44.35), "KGD": (54.89, 20.59), "MRV": (44.22, 43.08),
        "VVO": (43.40, 132.15), "KHV": (48.53, 135.19), "IKT": (52.27, 104.39),
        "GOJ": (56.23, 43.78), "CEK": (55.31, 61.50), "PEE": (57.91, 56.02),
        "TJM": (57.19, 65.32), "OMS": (54.97, 73.31), "MCX": (42.82, 47.65),
        // Japan
        "NRT": (35.76, 140.39), "HND": (35.55, 139.78), "KIX": (34.43, 135.24),
        "ITM": (34.79, 135.44), "CTS": (42.78, 141.69), "FUK": (33.59, 130.45),
        "NGO": (34.86, 136.80), "OKA": (26.20, 127.65),
        // China
        "PEK": (40.08, 116.60), "PKX": (39.51, 116.41), "PVG": (31.14, 121.81),
        "SHA": (31.20, 121.34), "CAN": (23.39, 113.30), "SZX": (22.64, 113.81),
        "CTU": (30.58, 103.95), "HGH": (30.23, 120.43), "XIY": (34.45, 108.75),
        "CKG": (29.72, 106.64),
        // Southeast Asia
        "BKK": (13.69, 100.75), "DMK": (13.91, 100.61), "HKT": (8.11, 98.32),
        "SIN": (1.35, 103.99), "KUL": (2.75, 101.71), "CGK": (-6.13, 106.66),
        "SGN": (10.82, 106.65), "HAN": (21.22, 105.81), "DPS": (-8.75, 115.17),
        "MNL": (14.51, 121.02), "RGN": (16.91, 96.13), "PNH": (11.55, 104.84),
        // Korea
        "ICN": (37.46, 126.44), "GMP": (37.56, 126.79), "PUS": (35.18, 128.94),
        "CJU": (33.51, 126.49),
        // India
        "DEL": (28.56, 77.10), "BOM": (19.09, 72.87), "BLR": (13.20, 77.71),
        "MAA": (12.99, 80.17), "CCU": (22.65, 88.45), "GOI": (15.38, 73.83),
        // Middle East
        "DXB": (25.25, 55.36), "AUH": (24.43, 54.65), "DOH": (25.26, 51.61),
        "RUH": (24.96, 46.70), "JED": (21.68, 39.16), "BAH": (26.27, 50.63),
        "MCT": (23.59, 58.28), "AMM": (31.72, 35.99), "BEY": (33.82, 35.49),
        "TLV": (32.01, 34.89),
        // Turkey
        "IST": (41.28, 28.75), "SAW": (40.90, 29.31), "AYT": (36.90, 30.80),
        "ADA": (36.98, 35.28), "ESB": (40.13, 32.99), "ADB": (38.29, 27.16),
        "DLM": (36.71, 28.79), "BJV": (37.25, 27.66),
        // Europe
        "CDG": (49.01, 2.55), "ORY": (48.72, 2.38),
        "LHR": (51.47, -0.45), "LGW": (51.15, -0.18), "STN": (51.89, 0.24),
        "FCO": (41.80, 12.24), "MXP": (45.63, 8.72), "VCE": (45.51, 12.35),
        "BCN": (41.30, 2.08), "MAD": (40.49, -3.57), "AGP": (36.67, -4.50),
        "FRA": (50.04, 8.56), "MUC": (48.35, 11.78),
        "TXL": (52.56, 13.29), "BER": (52.37, 13.50),
        "AMS": (52.31, 4.77), "BRU": (50.90, 4.48), "ZRH": (47.46, 8.55),
        "VIE": (48.11, 16.57), "PRG": (50.10, 14.26), "WAW": (52.17, 20.97),
        "BUD": (47.44, 19.26), "ATH": (37.94, 23.94), "LIS": (38.78, -9.14),
        "HEL": (60.32, 24.96), "ARN": (59.65, 17.92), "CPH": (55.62, 12.66),
        "OSL": (60.19, 11.10), "DUB": (53.43, -6.25),
        // CIS
        "TAS": (41.26, 69.28), "ALA": (43.35, 77.04), "NQZ": (51.02, 71.47),
        "TSE": (51.02, 71.47), "GYD": (40.47, 50.05), "TBS": (41.67, 44.95),
        "EVN": (40.15, 44.40), "MSQ": (53.88, 28.03), "KBP": (50.35, 30.89),
        "IEV": (50.40, 30.45), "FRU": (43.06, 74.48), "DYU": (38.54, 68.83),
        // Americas
        "JFK": (40.64, -73.78), "EWR": (40.69, -74.17), "LGA": (40.78, -73.87),
        "LAX": (33.94, -118.41), "SFO": (37.62, -122.38), "ORD": (41.97, -87.91),
        "MIA": (25.80, -80.29), "ATL": (33.64, -84.43), "DFW": (32.90, -97.04),
        "IAD": (38.95, -77.46), "DCA": (38.85, -77.04), "BOS": (42.37, -71.01),
        "SEA": (47.45, -122.31), "LAS": (36.08, -115.15), "DEN": (39.86, -104.67),
        "YYZ": (43.68, -79.63), "YVR": (49.20, -123.18),
        "MEX": (19.44, -99.07), "CUN": (21.04, -86.88),
        "GRU": (-23.44, -46.47), "GIG": (-22.81, -43.25),
        "EZE": (-34.82, -58.54), "SCL": (-33.39, -70.79),
        "BOG": (4.70, -74.15), "LIM": (-12.02, -77.11), "HAV": (22.99, -82.41),
        // Africa
        "CAI": (30.12, 31.41), "HRG": (27.18, 33.80), "SSH": (27.98, 34.40),
        "CMN": (33.37, -7.59), "JNB": (-26.14, 28.25), "CPT": (-33.97, 18.60),
        "NBO": (-1.32, 36.93), "ADD": (8.98, 38.80), "DSS": (14.74, -17.49),
        // Oceania
        "SYD": (-33.95, 151.18), "MEL": (-37.67, 144.84), "AKL": (-37.01, 174.79),
        // HK, Macau, Taiwan
        "HKG": (22.31, 113.92), "MFM": (22.15, 113.59), "TPE": (25.08, 121.23),
    ]
}
