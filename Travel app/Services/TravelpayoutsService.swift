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

        var p = ["origin": origin, "destination": destination, "departure_at": departureAt,
                 "currency": currency, "sorting": "price", "limit": "\(limit)", "unique": "false"]
        if let returnAt { p["return_at"] = returnAt }

        do {
            let data = try await SupabaseProxy.request(service: "travelpayouts", action: "flights", params: p)

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

        let p = ["location": location, "checkIn": checkIn, "checkOut": checkOut,
                 "currency": currency, "limit": "\(limit)"]

        do {
            let data = try await SupabaseProxy.request(service: "travelpayouts", action: "hotels", params: p)

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
        let p = ["origin": origin, "currency": currency, "period_type": "month",
                 "one_way": "false", "sorting": "price", "limit": "20"]

        do {
            let data = try await SupabaseProxy.request(service: "travelpayouts", action: "cheap", params: p)

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
