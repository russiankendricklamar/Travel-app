import Foundation

struct FlightOffer: Identifiable, Codable {
    var id: String { "\(origin)-\(destination)-\(departureAt)" }
    let origin: String
    let destination: String
    let departureAt: String
    let returnAt: String?
    let price: Int
    let airline: String
    let flightNumber: Int
    let transfers: Int
    let link: String

    var deepLink: String {
        "https://www.aviasales.ru\(link)"
    }
}

struct HotelOffer: Identifiable, Codable {
    var id: String { "\(hotelId)" }
    let hotelId: Int
    let hotelName: String
    let stars: Int
    let priceFrom: Double
    let pricePerNight: Double
    let locationName: String
    let link: String

    var deepLink: String {
        "https://search.hotellook.com/hotels?hotelId=\(hotelId)"
    }
}

@MainActor
@Observable
final class TravelpayoutsService {
    static let shared = TravelpayoutsService()
    private init() {}

    var lastError: String?

    // MARK: - Flights (Aviasales Prices API)
    func searchFlights(
        origin: String,
        destination: String,
        departureAt: String,
        returnAt: String? = nil,
        currency: String = "rub",
        limit: Int = 5
    ) async -> [FlightOffer] {
        lastError = nil
        let token = Secrets.travelpayoutsToken
        guard !token.isEmpty else {
            lastError = "Travelpayouts token not set"
            return []
        }

        var components = URLComponents(string: "https://api.travelpayouts.com/aviasales/v3/prices_for_dates")!
        components.queryItems = [
            URLQueryItem(name: "origin", value: origin),
            URLQueryItem(name: "destination", value: destination),
            URLQueryItem(name: "departure_at", value: departureAt),
            URLQueryItem(name: "currency", value: currency),
            URLQueryItem(name: "sorting", value: "price"),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "token", value: token),
            URLQueryItem(name: "unique", value: "false")
        ]
        if let returnAt { components.queryItems?.append(URLQueryItem(name: "return_at", value: returnAt)) }

        guard let url = components.url else { return [] }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                lastError = "HTTP error"
                return []
            }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let dataArray = json?["data"] as? [[String: Any]] else { return [] }

            return dataArray.prefix(limit).compactMap { item in
                guard let origin = item["origin"] as? String,
                      let dest = item["destination"] as? String,
                      let departure = item["departure_at"] as? String,
                      let price = item["price"] as? Int,
                      let airline = item["airline"] as? String,
                      let flightNum = item["flight_number"] as? Int,
                      let transfers = item["transfers"] as? Int,
                      let link = item["link"] as? String else { return nil }
                let returnDate = item["return_at"] as? String
                return FlightOffer(origin: origin, destination: dest, departureAt: departure,
                                   returnAt: returnDate, price: price, airline: airline,
                                   flightNumber: flightNum, transfers: transfers, link: link)
            }
        } catch {
            lastError = error.localizedDescription
            return []
        }
    }

    // MARK: - Hotels (Hotellook Cache API)
    func searchHotels(
        location: String,
        checkIn: String,
        checkOut: String,
        currency: String = "rub",
        limit: Int = 5
    ) async -> [HotelOffer] {
        lastError = nil
        let token = Secrets.travelpayoutsToken
        guard !token.isEmpty else {
            lastError = "Travelpayouts token not set"
            return []
        }

        var components = URLComponents(string: "https://engine.hotellook.com/api/v2/cache.json")!
        components.queryItems = [
            URLQueryItem(name: "location", value: location),
            URLQueryItem(name: "checkIn", value: checkIn),
            URLQueryItem(name: "checkOut", value: checkOut),
            URLQueryItem(name: "currency", value: currency),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "token", value: token)
        ]

        guard let url = components.url else { return [] }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                lastError = "HTTP error"
                return []
            }

            let items = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []

            return items.prefix(limit).compactMap { item in
                guard let hotelId = item["hotelId"] as? Int,
                      let hotelName = item["hotelName"] as? String,
                      let stars = item["stars"] as? Int,
                      let priceFrom = item["priceFrom"] as? Double else { return nil }
                let locationName = item["location"] as? [String: Any]
                let locName = locationName?["name"] as? String ?? location
                let nights = max(1, Calendar.current.dateComponents([.day], from: ISO8601DateFormatter().date(from: checkIn + "T00:00:00Z") ?? Date(), to: ISO8601DateFormatter().date(from: checkOut + "T00:00:00Z") ?? Date()).day ?? 1)
                return HotelOffer(hotelId: hotelId, hotelName: hotelName, stars: stars,
                                  priceFrom: priceFrom, pricePerNight: priceFrom / Double(nights),
                                  locationName: locName,
                                  link: "https://search.hotellook.com/hotels?hotelId=\(hotelId)")
            }
        } catch {
            lastError = error.localizedDescription
            return []
        }
    }

    // MARK: - Cheap Destinations (for "suggest me")
    func cheapDestinations(
        origin: String = "MOW",
        currency: String = "rub"
    ) async -> [(iata: String, price: Int, destination: String)] {
        let token = Secrets.travelpayoutsToken
        guard !token.isEmpty else { return [] }

        var components = URLComponents(string: "https://api.travelpayouts.com/aviasales/v3/get_latest_prices")!
        components.queryItems = [
            URLQueryItem(name: "origin", value: origin),
            URLQueryItem(name: "currency", value: currency),
            URLQueryItem(name: "period_type", value: "month"),
            URLQueryItem(name: "one_way", value: "false"),
            URLQueryItem(name: "sorting", value: "price"),
            URLQueryItem(name: "limit", value: "20"),
            URLQueryItem(name: "token", value: token)
        ]

        guard let url = components.url else { return [] }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return []
            }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let dataArray = json?["data"] as? [[String: Any]] else { return [] }

            return dataArray.compactMap { item in
                guard let dest = item["destination"] as? String,
                      let price = item["price"] as? Int else { return nil }
                let destName = item["destination"] as? String ?? dest
                return (iata: dest, price: price, destination: destName)
            }
        } catch {
            return []
        }
    }
}
