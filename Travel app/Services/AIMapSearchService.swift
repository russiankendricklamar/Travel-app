import Foundation
import CoreLocation
import MapKit

@MainActor
@Observable
final class AIMapSearchService {
    static let shared = AIMapSearchService()

    var isLoading = false
    var results: [PlaceRecommendation] = []
    var lastError: String?
    var clarificationMessage: String?

    private var cache: [String: [PlaceRecommendation]] = [:]

    private var provider: AIProvider {
        AIProvider.current
    }

    private var hasApiKey: Bool {
        GeminiService.shared.hasApiKey
    }

    // MARK: - Public Search

    func search(query: String, city: String, nearCoordinate: CLLocationCoordinate2D?, mapRegion: MKCoordinateRegion? = nil, tripID: UUID? = nil) async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let regionKey: String
        if let region = mapRegion {
            let c = region.center
            regionKey = "\(String(format: "%.2f", c.latitude)),\(String(format: "%.2f", c.longitude))"
        } else {
            regionKey = city.lowercased()
        }
        let cacheKey = "\(provider.rawValue):\(regionKey):\(trimmed.lowercased())"
        if let cached = cache[cacheKey] {
            results = cached
            clarificationMessage = nil
            return
        }

        isLoading = true
        lastError = nil
        clarificationMessage = nil
        defer { isLoading = false }

        let mapItems = await findPlacesOnAppleMaps(query: trimmed, region: mapRegion, near: nearCoordinate)

        guard !mapItems.isEmpty else {
            lastError = "Ничего не найдено на карте"
            return
        }

        let recommendations = await enrichMapItems(mapItems, userQuery: trimmed, tripID: tripID)

        results = recommendations
        cache[cacheKey] = recommendations
    }

    // MARK: - Public Enrichment

    /// Converts MKMapItems to PlaceRecommendations, optionally enriching via AI.
    func enrichMapItems(_ items: [MKMapItem], userQuery: String, tripID: UUID? = nil) async -> [PlaceRecommendation] {
        var recommendations = items.map { item in
            PlaceRecommendation(
                name: item.name ?? userQuery,
                description: "",
                category: Self.mapMKCategory(item.pointOfInterestCategory),
                estimatedTime: "",
                address: Self.formatAddress(item),
                latitude: item.placemark.coordinate.latitude,
                longitude: item.placemark.coordinate.longitude
            )
        }

        if hasApiKey {
            await enrichWithAI(&recommendations, userQuery: userQuery, tripID: tripID)
        }

        return recommendations
    }

    func clear() {
        results = []
        lastError = nil
        clarificationMessage = nil
    }

    // MARK: - Apple Maps Search (Source of Truth)

    private func findPlacesOnAppleMaps(
        query: String,
        region: MKCoordinateRegion?,
        near coordinate: CLLocationCoordinate2D?
    ) async -> [MKMapItem] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.pointOfInterest, .address]

        if let region {
            request.region = region
        } else if let coord = coordinate {
            request.region = MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
            )
        }

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            return Array(response.mapItems.prefix(6))
        } catch {
            return []
        }
    }

    // MARK: - AI Enrichment

    private func enrichWithAI(_ items: inout [PlaceRecommendation], userQuery: String, tripID: UUID? = nil) async {
        let placeNames = items.map { "\($0.name) (\($0.address))" }.joined(separator: "\n")

        let profileCtx = AIPromptHelper.profileContext()

        let prompt = """
        Пользователь искал "\(userQuery)". Найдены места:

        \(placeNames)

        Для каждого — живое описание (не из путеводителя, а как рассказал бы друг). JSON:
        {"places":[{"name":"Точное имя","description":"1-2 предложения на языке запроса","category":"restaurant|museum|temple|shrine|park|cafe|bar|shopping|entertainment|architecture|nature|hotel|airport|landmark|viewpoint|beach|palace|bridge","estimated_time":"1-2 часа","local_name":"Название на местном языке"}]}
        \(profileCtx)

        Ровно \(items.count) записей, тот же порядок. Только JSON, без markdown.
        """

        let aiCacheKey = "ai:mapsearch:\(userQuery.lowercased())"
        if let cached = AICacheManager.shared.get(key: aiCacheKey),
           let enrichment = parseEnrichment(from: cached) {
            for i in items.indices {
                guard i < enrichment.places.count else { break }
                let info = enrichment.places[i]
                if !info.description.isEmpty {
                    items[i] = PlaceRecommendation(
                        id: items[i].id,
                        name: items[i].name,
                        description: info.description,
                        category: Self.mapCategory(info.category),
                        estimatedTime: info.estimatedTime ?? items[i].estimatedTime,
                        address: items[i].address,
                        latitude: items[i].latitude,
                        longitude: items[i].longitude,
                        localName: info.localName ?? ""
                    )
                }
            }
            return
        }

        let rawContent = await GeminiService.shared.rawRequest(prompt: prompt)

        guard let content = rawContent,
              let enrichment = parseEnrichment(from: content) else {
            return
        }

        for i in items.indices {
            guard i < enrichment.places.count else { break }
            let info = enrichment.places[i]
            if !info.description.isEmpty {
                items[i] = PlaceRecommendation(
                    id: items[i].id,
                    name: items[i].name,
                    description: info.description,
                    category: Self.mapCategory(info.category),
                    estimatedTime: info.estimatedTime ?? items[i].estimatedTime,
                    address: items[i].address,
                    latitude: items[i].latitude,
                    longitude: items[i].longitude,
                    localName: info.localName ?? ""
                )
            }
        }

        if let content = rawContent {
            AICacheManager.shared.set(key: aiCacheKey, response: content, tripID: tripID)
        }
    }

    // MARK: - Category Mapping

    private static let categoryMap: [String: String] = [
        "restaurant": "Еда",
        "cafe": "Еда",
        "bar": "Развлечения",
        "food": "Еда",
        "museum": "Культура",
        "culture": "Культура",
        "temple": "Храм",
        "shrine": "Святилище",
        "park": "Природа",
        "nature": "Природа",
        "shopping": "Шопинг",
        "entertainment": "Развлечения",
        "architecture": "Архитектура",
        "hotel": "Жильё",
        "airport": "Транспорт",
        "landmark": "Достопримечательность",
        "viewpoint": "Природа",
        "beach": "Природа",
        "palace": "Архитектура",
        "bridge": "Архитектура",
    ]

    private static func mapCategory(_ english: String) -> String {
        categoryMap[english.lowercased()] ?? "Культура"
    }

    static func mapMKCategory(_ category: MKPointOfInterestCategory?) -> String {
        guard let category else { return "Культура" }
        switch category {
        case .restaurant, .bakery, .brewery, .winery:
            return "Еда"
        case .cafe:
            return "Еда"
        case .nightlife:
            return "Развлечения"
        case .hotel:
            return "Жильё"
        case .museum:
            return "Культура"
        case .theater, .movieTheater:
            return "Развлечения"
        case .park, .nationalPark, .beach:
            return "Природа"
        case .store:
            return "Шопинг"
        case .airport:
            return "Транспорт"
        case .publicTransport:
            return "Транспорт"
        default:
            return "Культура"
        }
    }

    static func formatAddress(_ item: MKMapItem) -> String {
        let placemark = item.placemark
        let parts = [
            placemark.thoroughfare,
            placemark.subThoroughfare,
            placemark.locality,
            placemark.administrativeArea
        ].compactMap { $0 }
        return parts.isEmpty ? (item.name ?? "") : parts.joined(separator: ", ")
    }

    // MARK: - JSON Parsing

    private func parseEnrichment(from text: String) -> AIEnrichmentResponse? {
        var cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let start = cleaned.firstIndex(of: "{"),
              let end = cleaned.lastIndex(of: "}") else { return nil }

        cleaned = String(cleaned[start...end])

        guard let data = cleaned.data(using: .utf8) else { return nil }

        do {
            return try JSONDecoder().decode(AIEnrichmentResponse.self, from: data)
        } catch {
            return nil
        }
    }
}

// MARK: - AI Response Models

private struct AIEnrichmentResponse: Codable {
    let places: [AIEnrichmentPlace]
}

private struct AIEnrichmentPlace: Codable {
    let name: String
    let description: String
    let category: String
    let estimatedTime: String?
    let localName: String?

    enum CodingKeys: String, CodingKey {
        case name, description, category
        case estimatedTime = "estimated_time"
        case localName = "local_name"
    }
}
