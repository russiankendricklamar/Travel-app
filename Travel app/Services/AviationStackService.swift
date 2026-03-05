import Foundation

@Observable
final class AviationStackService {
    static let shared = AviationStackService()

    var isLoading = false
    var lastError: String?
    var cachedFlight: FlightData?
    private var lastFetchedNumber: String?
    private var lastFetchDate: Date?
    private let cacheInterval: TimeInterval = 300

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)
    }

    var hasApiKey: Bool {
        !Secrets.aviationStackApiKey.isEmpty
    }

    func fetchFlight(number: String) async -> FlightData? {
        let cleaned = number.replacingOccurrences(of: " ", with: "").uppercased()

        if let cached = cachedFlight,
           lastFetchedNumber == cleaned,
           let lastDate = lastFetchDate,
           Date().timeIntervalSince(lastDate) < cacheInterval {
            return cached
        }

        guard hasApiKey else {
            lastError = "API-ключ AviationStack не настроен"
            return nil
        }

        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            let key = Secrets.aviationStackApiKey
            let urlString = "http://api.aviationstack.com/v1/flights?access_key=\(key)&flight_iata=\(cleaned)"
            guard let url = URL(string: urlString) else {
                lastError = "Неверный номер рейса"
                return nil
            }

            let (data, response) = try await session.data(from: url)

            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                lastError = "Ошибка сервера"
                return nil
            }

            let decoded = try JSONDecoder().decode(AviationStackResponse.self, from: data)
            guard let first = decoded.data.first else {
                lastError = "Рейс не найден"
                return nil
            }

            let flight = FlightData(from: first)
            cachedFlight = flight
            lastFetchedNumber = cleaned
            lastFetchDate = Date()
            return flight
        } catch {
            lastError = "Не удалось загрузить данные о рейсе"
            return nil
        }
    }
}

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

    var isDelayed: Bool {
        (departureDelay ?? 0) > 0 || (arrivalDelay ?? 0) > 0
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
}

private struct AviationStackResponse: Codable {
    let data: [FlightEntry]
}

private struct FlightEntry: Codable {
    let flight_date: String?
    let flight_status: String?
    let departure: AirportInfo?
    let arrival: AirportInfo?
    let airline: AirlineInfo?
    let flight: FlightEntryInfo?
}

private struct AirportInfo: Codable {
    let airport: String?
    let iata: String?
    let scheduled: String?
    let estimated: String?
    let gate: String?
    let terminal: String?
    let delay: Int?
}

private struct AirlineInfo: Codable {
    let name: String?
    let iata: String?
}

private struct FlightEntryInfo: Codable {
    let iata: String?
}

extension FlightData {
    fileprivate init(from entry: FlightEntry) {
        self.flightIata = entry.flight?.iata ?? ""
        self.airlineName = entry.airline?.name ?? ""
        self.status = entry.flight_status ?? "scheduled"
        self.departureAirport = entry.departure?.airport ?? ""
        self.departureIata = entry.departure?.iata ?? ""
        self.departureTime = Self.parseDate(entry.departure?.scheduled)
        self.departureEstimated = Self.parseDate(entry.departure?.estimated)
        self.departureGate = entry.departure?.gate
        self.departureTerminal = entry.departure?.terminal
        self.departureDelay = entry.departure?.delay
        self.arrivalAirport = entry.arrival?.airport ?? ""
        self.arrivalIata = entry.arrival?.iata ?? ""
        self.arrivalTime = Self.parseDate(entry.arrival?.scheduled)
        self.arrivalEstimated = Self.parseDate(entry.arrival?.estimated)
        self.arrivalGate = entry.arrival?.gate
        self.arrivalTerminal = entry.arrival?.terminal
        self.arrivalDelay = entry.arrival?.delay
    }

    private static func parseDate(_ string: String?) -> Date? {
        guard let string else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}
