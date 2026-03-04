import Foundation
import CoreLocation

struct POIResult: Identifiable {
    let id: String
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let rating: Double?
    let totalRatings: Int?
    let isOpenNow: Bool?
    let photoReference: String?
    let distanceMeters: Double?
}

enum GooglePOICategory: String, CaseIterable, Identifiable {
    case restaurant = "restaurant"
    case attraction = "tourist_attraction"
    case museum = "museum"
    case shopping = "shopping_mall"
    case cafe = "cafe"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .restaurant: return "Рестораны"
        case .attraction: return "Достопримечательности"
        case .museum: return "Музеи"
        case .shopping: return "Шопинг"
        case .cafe: return "Кафе"
        }
    }

    var systemImage: String {
        switch self {
        case .restaurant: return "fork.knife"
        case .attraction: return "star.fill"
        case .museum: return "building.columns"
        case .shopping: return "bag.fill"
        case .cafe: return "cup.and.saucer.fill"
        }
    }

    var googleTypes: [String] {
        switch self {
        case .restaurant: return ["restaurant"]
        case .attraction: return ["tourist_attraction"]
        case .museum: return ["museum"]
        case .shopping: return ["shopping_mall", "store"]
        case .cafe: return ["cafe"]
        }
    }
}

@MainActor @Observable
final class GooglePlacesService {
    static let shared = GooglePlacesService()
    private init() {}

    var isLoading = false
    var errorMessage: String?

    private var cache: [String: [POIResult]] = [:]

    private var apiKey: String { Secrets.googlePlacesApiKey }
    var hasApiKey: Bool { !apiKey.trimmingCharacters(in: .whitespaces).isEmpty }

    func searchNearby(coordinate: CLLocationCoordinate2D, category: GooglePOICategory, radiusMeters: Double = 1500) async -> [POIResult] {
        let cacheKey = "\(Int(coordinate.latitude * 100)),\(Int(coordinate.longitude * 100))_\(category.rawValue)"
        if let cached = cache[cacheKey] { return cached }

        guard hasApiKey else {
            errorMessage = "Нет API-ключа Google Places"
            return []
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let url = URL(string: "https://places.googleapis.com/v1/places:searchNearby") else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue("places.id,places.displayName,places.formattedAddress,places.location,places.rating,places.userRatingCount,places.currentOpeningHours,places.photos", forHTTPHeaderField: "X-Goog-FieldMask")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "includedTypes": category.googleTypes,
            "maxResultCount": 20,
            "locationRestriction": [
                "circle": [
                    "center": ["latitude": coordinate.latitude, "longitude": coordinate.longitude],
                    "radius": radiusMeters
                ]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                errorMessage = "Ошибка сервера"
                return []
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let places = json["places"] as? [[String: Any]] else {
                return []
            }

            let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let results: [POIResult] = places.compactMap { place in
                guard let id = place["id"] as? String,
                      let displayName = place["displayName"] as? [String: Any],
                      let name = displayName["text"] as? String,
                      let location = place["location"] as? [String: Any],
                      let lat = location["latitude"] as? Double,
                      let lon = location["longitude"] as? Double else { return nil }

                let address = place["formattedAddress"] as? String ?? ""
                let rating = place["rating"] as? Double
                let totalRatings = place["userRatingCount"] as? Int
                let openingHours = place["currentOpeningHours"] as? [String: Any]
                let isOpen = openingHours?["openNow"] as? Bool
                let photos = place["photos"] as? [[String: Any]]
                let photoRef = (photos?.first?["name"] as? String)

                let dest = CLLocation(latitude: lat, longitude: lon)
                let distance = origin.distance(from: dest)

                return POIResult(
                    id: id, name: name, address: address,
                    latitude: lat, longitude: lon,
                    rating: rating, totalRatings: totalRatings,
                    isOpenNow: isOpen, photoReference: photoRef,
                    distanceMeters: distance
                )
            }.sorted { ($0.distanceMeters ?? 0) < ($1.distanceMeters ?? 0) }

            cache[cacheKey] = results
            return results
        } catch {
            errorMessage = "Не удалось загрузить"
            return []
        }
    }
}
