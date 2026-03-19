import Foundation
import CoreLocation

/// Детали места из Google Places API (New).
struct GooglePlaceDetail {
    let placeId: String
    let rating: Double?
    let userRatingCount: Int?
    let priceLevel: String?
    let formattedAddress: String?
    let phone: String?
    let website: String?
    let googleMapsURL: String?
    let openNow: Bool?
    let weekdayHours: [String]
    let reviews: [GooglePlaceReview]
    let photoURLs: [URL]
}

struct GooglePlaceReview {
    let authorName: String
    let rating: Int
    let text: String
    let relativeTime: String
}

/// Сервис для получения деталей места через Google Places API (через Supabase proxy).
@Observable
final class PlaceDetailService {
    static let shared = PlaceDetailService()
    private init() {}

    private var cache: [String: GooglePlaceDetail] = [:]

    /// Найти детали места по имени и координатам.
    func fetchDetails(
        name: String,
        coordinate: CLLocationCoordinate2D
    ) async -> GooglePlaceDetail? {
        let cacheKey = "\(name)_\(String(format: "%.4f,%.4f", coordinate.latitude, coordinate.longitude))"
        if let cached = cache[cacheKey] { return cached }

        do {
            let data = try await SupabaseProxy.request(
                service: "google_places",
                action: "search_text",
                params: [
                    "query": name,
                    "latitude": String(coordinate.latitude),
                    "longitude": String(coordinate.longitude),
                    "language": "ru"
                ]
            )

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let places = json["places"] as? [[String: Any]],
                  let place = places.first else {
                return nil
            }

            let detail = parsePlace(place)
            cache[cacheKey] = detail
            return detail
        } catch {
            print("[PlaceDetailService] Error fetching details for '\(name)': \(error)")
            return nil
        }
    }

    func clearCache() {
        cache.removeAll()
    }

    // MARK: - Parsing

    private func parsePlace(_ json: [String: Any]) -> GooglePlaceDetail {
        let placeId = json["id"] as? String ?? ""
        let rating = json["rating"] as? Double
        let userRatingCount = json["userRatingCount"] as? Int
        let priceLevel = json["priceLevel"] as? String
        let formattedAddress = json["formattedAddress"] as? String
        let phone = json["internationalPhoneNumber"] as? String
        let website = json["websiteUri"] as? String
        let googleMapsURL = json["googleMapsUri"] as? String

        // Opening hours
        var openNow: Bool?
        var weekdayHours: [String] = []

        if let currentHours = json["currentOpeningHours"] as? [String: Any] {
            openNow = currentHours["openNow"] as? Bool
            weekdayHours = (currentHours["weekdayDescriptions"] as? [String]) ?? []
        } else if let regularHours = json["regularOpeningHours"] as? [String: Any] {
            openNow = regularHours["openNow"] as? Bool
            weekdayHours = (regularHours["weekdayDescriptions"] as? [String]) ?? []
        }

        // Photos
        var photoURLs: [URL] = []
        if let photos = json["photos"] as? [[String: Any]] {
            let baseURL = "\(Secrets.supabaseURL)/functions/v1/api-proxy/photo"
            photoURLs = photos.prefix(5).compactMap { photo in
                guard let name = photo["name"] as? String else { return nil }
                var components = URLComponents(string: baseURL)
                components?.queryItems = [
                    URLQueryItem(name: "name", value: name),
                    URLQueryItem(name: "maxWidthPx", value: "800"),
                ]
                return components?.url
            }
        }

        // Reviews
        var reviews: [GooglePlaceReview] = []
        if let rawReviews = json["reviews"] as? [[String: Any]] {
            reviews = rawReviews.prefix(3).compactMap { r in
                let authorDict = r["authorAttribution"] as? [String: Any]
                let authorName = authorDict?["displayName"] as? String ?? ""
                let ratingVal = r["rating"] as? Int ?? 0
                let textDict = r["text"] as? [String: Any]
                let text = textDict?["text"] as? String ?? ""
                let relTime = r["relativePublishTimeDescription"] as? String ?? ""
                guard !text.isEmpty else { return nil }
                return GooglePlaceReview(
                    authorName: authorName,
                    rating: ratingVal,
                    text: text,
                    relativeTime: relTime
                )
            }
        }

        return GooglePlaceDetail(
            placeId: placeId,
            rating: rating,
            userRatingCount: userRatingCount,
            priceLevel: priceLevel,
            formattedAddress: formattedAddress,
            phone: phone,
            website: website,
            googleMapsURL: googleMapsURL,
            openNow: openNow,
            weekdayHours: weekdayHours,
            reviews: reviews,
            photoURLs: photoURLs
        )
    }
}
